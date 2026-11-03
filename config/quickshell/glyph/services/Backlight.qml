pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// the screen backlight, like in caelestia — the device isn't hard-coded: whatever brightnessctl takes by default (the first backlight).
// The value — from sysfs: inotify is silent on it, but a write to brightness sends a uevent change — we wait for it from udev rather than polling.
// No backlight (a desktop PC) — dev is empty, value 0. ponytail: external monitors over DDC (ddcutil, like caelestia) — not supported
Singleton {
    id: root

    property string dev: ""       // /sys/class/backlight/<name>
    property real value: 0        // 0…1
    property int steps: 20        // scale steps for the keys; glyph sets it from the settings (Sys)
    signal moved()                // every uevent, even if the value is the same (the key at maximum) — for the OSD

    function read() {
        cur.reload();
        const v = parseInt(cur.text());
        if (!isNaN(v)) value = v / (parseInt(max.text()) || 1);
    }
    // value is set at once, without waiting for brightnessctl and the uevent; while our own writes are in flight, their uevents aren't read — sync checks later
    // as a raw number, not a percentage: rounding to % would throw off the step() grid (81 % → up → 99, not 100)
    function set(v) {
        const m = parseInt(max.text()) || 0;
        if (!m) return;
        const raw = Math.round(Math.max(0.01, Math.min(1, v)) * m);
        value = raw / m;
        sync.restart();
        Quickshell.execDetached(["brightnessctl", "-q", "-d", dev.slice(dev.lastIndexOf("/") + 1), "set", String(raw)]);
    }
    // keys: steps divisions along a 4th root (20 — like brightnessctl -e4 5%), finer at the bottom of the scale. The step from the nearest
    // division, not from value: otherwise a fractional error accumulates (up to 399998 instead of 400000)
    function step(d) {
        set(Math.pow(Math.max(0, Math.min(steps, Math.round(Math.pow(value, 0.25) * steps) + d)) / steps, 4));
        moved();
    }
    Timer { id: sync; interval: 300; onTriggered: root.read() }
    GlobalShortcut { appid: "shell"; name: "briUp"; description: "brightness +"; onPressed: root.step(1) }
    GlobalShortcut { appid: "shell"; name: "briDown"; description: "brightness −"; onPressed: root.step(-1) }

    FileView { id: cur; path: root.dev ? root.dev + "/brightness" : ""; blockAllReads: true; printErrors: false }
    FileView { id: max; path: root.dev ? root.dev + "/max_brightness" : ""; blockLoading: true; printErrors: false }

    // brightnessctl -m: «name,class,current,percent,max»
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim().split(",")[0];
                if (!name) return;
                root.dev = "/sys/class/backlight/" + name;
                root.read();
            }
        }
    }

    // ---- внешний монитор по DDC (ddcutil): шина ищем парами «I2C bus → DRM_connector», внешняя — коннектор без eDP.
    // udev-правило logind даёт активному пользователю rw на /dev/i2c-*, sudo не нужен. Событий смены нет —
    // значение держим своё, раз в 5 с сверяем getvcp, при drag'е панели ставим сразу ----
    property string ddcBus: ""      // /dev/i2c-N, пусто — внешнего с DDC нет
    property real ddc: 0.5          // последнее известное 0…1
    property bool ddcOk: false
    signal ddcMoved()
    Timer {
        running: !!root.ddcBus
        interval: 5000
        repeat: true
        onTriggered: root.ddcRead()
    }
    function ddcRead() {
        ddcGet.exec(["ddcutil", "--noverify", "--sleep-multiplier", "0.05", "--brief", "getvcp", "10"]);
    }
    Process {
        id: ddcGet
        stdout: StdioCollector {
            onStreamFinished: {
                // «VCP 10 C 50 100» — код, тип, текущее, максимум
                const p = text.trim().split(/\s+/);
                const v = parseFloat(p[3]), m = parseFloat(p[4]);
                if (!isNaN(v) && m > 0) {
                    root.ddc = v / m;
                    root.ddcOk = true;
                    root.ddcMoved();
                }
            }
        }
    }
    function setDdc(v) {
        if (!ddcBus)
            return;
        const val = Math.round(Math.max(0, Math.min(1, v)) * 100);
        ddc = val / 100;
        ddcOk = true;
        ddcMoved();
        // ddcutil сам вешает flock на шину — сливаю writes: последний за 80 мс побеждает, спам при drag'е
        // не плодит процессы и не дерётся с опросом (flock wait до 3 с). Проц дс: 80 мс ≈ 12 шагов/с — глазом плавно
        const cmd = ["ddcutil", "--noverify", "--sleep-multiplier", "0.05", "setvcp", "10", String(val)];
        ddcSetQueued = cmd;
        if (!ddcSetTimer.running)
            ddcSetTimer.restart();
    }
    property var ddcSetQueued: null
    Timer {
        id: ddcSetTimer
        interval: 80
        onTriggered: {
            if (root.ddcSetQueued)
                Quickshell.execDetached(root.ddcSetQueued);
            root.ddcSetQueued = null;
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "ddcutil detect 2>/dev/null | awk '/I2C bus/{b=$NF} /DRM_connector/{c=$NF} /EDID synopsis/{if (b && c && index(c, \"eDP\") == 0) {print b; exit}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bus = text.trim();
                if (bus.startsWith("/dev/i2c")) {
                    root.ddcBus = bus;
                    root.ddcRead();
                }
            }
        }
    }
    Process {
        running: !!root.dev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser { onRead: l => { if (l.includes(" change ")) { if (!sync.running) root.read(); root.moved(); } } }
    }
}
