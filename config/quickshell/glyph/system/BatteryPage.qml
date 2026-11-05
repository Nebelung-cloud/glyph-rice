import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components
import "../prefs"

// battery: the charge as a ring, how much is left, health (now versus new), cycles, and how to charge — whatever the kernel offers:
// charge_types (fast · standard · long life), a stop/start threshold in percent (thinkpad, asus, dell…) or the old
// conservation_mode on ideapad. Only root can write there — it asks for a password (pkexec), unless udev opened the file
Page {
    id: root
    property bool live
    readonly property var bat: UPower.displayDevice
    readonly property bool has: bat?.isLaptopBattery ?? false
    caption: `battery · ${UPower.onBattery ? "on battery" : "plugged in"}`

    // ---- sysfs: the path, cycles, design capacity, the ways to limit the charge and whether we can write without root ----
    property var sys: ({})
    function read() { probe.running = true; }
    onLiveChanged: if (live) read()
    Process {
        id: probe
        command: ["sh", "-c", `for b in /sys/class/power_supply/*; do [ "$(cat "$b/type")" = Battery ] && [ "$(cat "$b/scope" 2>/dev/null)" != Device ] && break; done
echo "path=$b"
for f in cycle_count energy_full_design charge_types charge_control_end_threshold charge_control_start_threshold manufacturer model_name; do
  [ -r "$b/$f" ] && echo "$f=$(cat "$b/$f")" && [ -w "$b/$f" ] && echo "w_$f=1"; done
c=$(ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode 2>/dev/null | head -n1)
[ -n "$c" ] && echo "conservation=$(cat "$c")" && echo "conservation_path=$c" && [ -w "$c" ] && echo "w_conservation=1"
true`]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0) m[l.slice(0, i)] = l.slice(i + 1);
                }
                root.sys = m;
            }
        }
    }
    // "Fast [Standard] Long_Life" → the options and the selected one
    readonly property var types: (sys.charge_types ?? "").split(/\s+/).filter(Boolean).map(x => x.replace(/[\[\]]/g, ""))
    readonly property string type: ((sys.charge_types ?? "").match(/\[(\w+)\]/) ?? [])[1] ?? ""
    readonly property var typeNames: ({ Fast: "fast", Standard: "standard", Long_Life: "long life", Adaptive: "adaptive", Custom: "custom", Trickle: "trickle" })

    // ---- writing: open to us — we write ourselves, otherwise via pkexec. The path — only from probe, the value — from our own options ----
    property string msg
    function put(file, value) {
        const path = file === "conservation" ? sys.conservation_path : `${sys.path}/${file}`;
        const own = sys[`w_${file}`] === "1";
        const sh = 'printf %s "$1" > "$2"';
        write.command = own ? ["sh", "-c", sh, "sh", String(value), path] : ["pkexec", "sh", "-c", sh, "sh", String(value), path];
        msg = own ? "" : "asking for your password…";
        write.running = true;
    }
    Process {
        id: write
        onExited: code => {
            root.msg = code === 0 ? "" : code === 126 || code === 127 ? "not changed · password dialog closed" : "the kernel refused this value";
            root.read();
        }
    }

    function hm(s) {
        if (!s) return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h ? `${h} h ${m} m` : `${m} m`;
    }
    readonly property string state: !has ? "" : bat.state === UPowerDeviceState.Charging ? `charging${bat.timeToFull ? ` · ${hm(bat.timeToFull)} to full` : ""}`
        : bat.state === UPowerDeviceState.FullyCharged ? "full"
        : bat.state === UPowerDeviceState.Discharging ? `${hm(bat.timeToEmpty) || "on battery"}${bat.timeToEmpty ? " left" : ""}`
        : "not charging"
    readonly property real health: has && +sys.energy_full_design ? bat.energyCapacity / (+sys.energy_full_design / 1e6) : bat?.healthPercentage / 100 || 0

    Lb { visible: !root.has; text: "no battery on this machine" }

    Row {
        visible: root.has
        spacing: 60
        Item {
            width: 300
            height: 300
            Ring { anchors.fill: parent; n: 48; dot: 9; f: (root.bat?.percentage ?? 0) }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    Num { id: pct; text: Math.round((root.bat?.percentage ?? 0) * 100); font.pixelSize: 96 }
                    Num { anchors.baseline: pct.baseline; text: "%"; font.pixelSize: 40; color: Theme.mute }
                }
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.state }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Lb { text: "health" }
            Row {
                spacing: 8
                Num { id: hp; text: Math.round(root.health * 100); font.pixelSize: 72 }
                Num { anchors.baseline: hp.baseline; text: "%"; font.pixelSize: 32; color: Theme.mute }
            }
            Lb { text: `${(root.bat?.energyCapacity ?? 0).toFixed(1)} of ${(+(root.sys.energy_full_design ?? 0) / 1e6).toFixed(1)} wh${root.sys.cycle_count ? ` · ${root.sys.cycle_count} cycles` : ""}` }
            Lb { visible: Math.abs(root.bat?.changeRate ?? 0) > 0.1; text: `${UPower.onBattery ? "using" : "charging at"} ${Math.abs(root.bat?.changeRate ?? 0).toFixed(1)} w` }
            Lb { text: [root.sys.manufacturer, root.sys.model_name].filter(Boolean).join(" · ") }
        }
    }

    // ---- how to charge: what this laptop has ----
    Column {
        visible: root.has
        spacing: 14
        Pick {
            visible: root.types.length > 1
            label: "charging"
            opts: root.types.map(t => root.typeNames[t] ?? t.toLowerCase())
            cur: root.types.indexOf(root.type)
            onPicked: i => root.put("charge_types", root.types[i])
        }
        Row {
            visible: !root.types.length && root.sys.charge_control_end_threshold !== undefined
            spacing: 40
            Dial { label: "stop at · %"; from: 50; to: 100; step: 5; value: +(root.sys.charge_control_end_threshold ?? 100); onMoved: v => root.put("charge_control_end_threshold", v) }
            Dial { visible: root.sys.charge_control_start_threshold !== undefined; label: "start at · %"; from: 0; to: 95; step: 5; value: +(root.sys.charge_control_start_threshold ?? 0); onMoved: v => root.put("charge_control_start_threshold", v) }
        }
        Toggle {
            visible: !root.types.length && root.sys.charge_control_end_threshold === undefined && root.sys.conservation !== undefined
            text: "conservation · stops early"
            on: root.sys.conservation === "1"
            onFlip: root.put("conservation", on ? 0 : 1)
        }
        Lb {
            visible: root.types.includes("Long_Life") || root.sys.charge_control_end_threshold !== undefined || root.sys.conservation !== undefined
            text: "plugged in most of the time? stopping early keeps the battery healthy for longer"
        }
        Lb { visible: !!root.msg; text: root.msg; color: root.msg.startsWith("asking") ? Theme.fg : Theme.red }
    }
}
