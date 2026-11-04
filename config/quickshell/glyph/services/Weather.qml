pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// open-meteo weather every 30 min. Location: DEMONSHOT_LATLON="52.52,13.40", otherwise by IP (ipinfo.io)
Singleton {
    id: root

    property string loc: Quickshell.env("DEMONSHOT_LATLON") ?? ""
    property var now: null     // { temp, feels, code, wind, windDir, gusts, humidity, pressure, rain, day }
    property var days: []      // [{ date, code, max, min, rain }]
    property var sun: null     // { rise, set } — today's Date
    readonly property bool ok: now !== null

    readonly property var names: ({ 0: "clear", 1: "mostly clear", 2: "cloudy", 3: "overcast", 45: "fog", 48: "fog",
        51: "drizzle", 53: "drizzle", 55: "drizzle", 56: "ice drizzle", 57: "ice drizzle", 61: "rain", 63: "rain", 65: "heavy rain",
        66: "ice rain", 67: "ice rain", 71: "snow", 73: "snow", 75: "heavy snow", 77: "snow grains", 80: "showers", 81: "showers",
        82: "storm showers", 85: "snow showers", 86: "snow showers", 95: "thunder", 96: "thunder", 99: "thunder" })

    function glyph(code, day) {
        if (code <= 1) return day === false ? "\u{F0594}" : "\u{F0599}";
        if (code === 2) return "\u{F0595}";
        if (code === 3) return "\u{F0590}";
        if (code < 50) return "\u{F0591}";
        if (code >= 95) return "\u{F0593}";
        if (code >= 71 && code <= 77 || code === 85 || code === 86) return "\u{F0598}";
        return "\u{F0597}";
    }
    function name(code) { return names[code] ?? "omens"; }
    function compass(deg) { return ["n", "ne", "e", "se", "s", "sw", "w", "nw"][Math.round(deg / 45) % 8]; }

    // moon phase: 0 — new moon, 0.5 — full moon
    function moonPhase(d) {
        const p = ((d.getTime() / 86400000 - 10962.76) / 29.530588) % 1; // from the new moon of 2000-01-06 18:14 UTC
        return p < 0 ? p + 1 : p;
    }

    // the location — from refresh(): the network may not be up yet at startup, then a retry, like the weather
    Process {
        id: where
        command: ["curl", "-sf", "--max-time", "10", "https://ipinfo.io/loc"]
        onExited: code => { if (code !== 0) retry.restart(); }
        stdout: StdioCollector { onStreamFinished: if (text.trim().match(/^-?[\d.]+,-?[\d.]+$/)) root.loc = text.trim() }
    }

    // open-meteo is sometimes overloaded — then a retry after 2 min
    function refresh() {
        if (!loc) return where.running = true;
        const [lat, lon] = loc.split(",");
        fetch.command = ["curl", "-sf", "--max-time", "15", `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}`
            + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,relative_humidity_2m,surface_pressure,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"
            + "&wind_speed_unit=ms&timezone=auto&forecast_days=5"];
        fetch.running = true;
    }

    Timer { id: retry; interval: 120000; onTriggered: root.refresh() }

    Process {
        id: fetch
        onExited: code => { if (code !== 0) retry.restart(); }
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try { j = JSON.parse(text); } catch (e) { return; }
                const c = j.current, d = j.daily;
                root.now = { temp: c.temperature_2m, feels: c.apparent_temperature, code: c.weather_code, wind: c.wind_speed_10m,
                    windDir: c.wind_direction_10m, gusts: c.wind_gusts_10m, humidity: c.relative_humidity_2m,
                    pressure: c.surface_pressure, rain: c.precipitation_probability, day: c.is_day === 1 };
                root.days = d.time.map((t, i) => ({ date: new Date(t), code: d.weather_code[i], max: d.temperature_2m_max[i],
                    min: d.temperature_2m_min[i], rain: d.precipitation_probability_max[i] }));
                root.sun = { rise: new Date(d.sunrise[0]), set: new Date(d.sunset[0]) };
            }
        }
    }

    onLocChanged: refresh()
    Component.onCompleted: refresh()

    Timer {
        interval: 30 * 60 * 1000
        running: root.loc !== ""
        repeat: true
        onTriggered: root.refresh()
    }
}
