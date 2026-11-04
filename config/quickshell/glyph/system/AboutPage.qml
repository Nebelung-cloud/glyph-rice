import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import "../prefs"

// about the system: model, system, kernel, processor, graphics (and the nvidia driver version), memory, disk, bios, hyprland, quickshell.
// Updates: checkupdates (pacman-contrib) and AUR via yay/paru — a count and a list; «update» opens kitty with the upgrade
Page {
    id: root
    property bool live
    caption: `about · ${info.host ?? ""}`

    property var info: ({})
    Process {
        id: probe
        running: root.live && !root.info.os
        command: ["sh", "-c", `. /etc/os-release 2>/dev/null; echo "os=$PRETTY_NAME"
echo "host=$(cat /proc/sys/kernel/hostname)"
v=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null); p=$(cat /sys/class/dmi/id/product_version 2>/dev/null)
case "$p" in ""|*"System Version"*|*"To be filled"*|*"Default"*) p=$(cat /sys/class/dmi/id/product_name 2>/dev/null);; esac
echo "model=$v $p"
echo "kernel=$(uname -r)"
echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "cores=$(nproc)"
lspci -mm 2>/dev/null | grep -E '"(VGA|3D|Display)' | sed -E 's/^[^"]*"[^"]*" "([^"]*)" "([^"]*)".*/gpu=\\1 \\2/'
[ -r /sys/module/nvidia/version ] && echo "nvidia=$(cat /sys/module/nvidia/version)"
echo "mem=$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo)"
df -h / | awk 'NR==2 {print "disk=" $3 " of " $2}'
echo "bios=$(cat /sys/class/dmi/id/bios_version 2>/dev/null) · $(cat /sys/class/dmi/id/bios_date 2>/dev/null)"
echo "hypr=$(hyprctl version -j 2>/dev/null | grep -m1 '"tag"' | cut -d'"' -f4)"
echo "qs=$(qs --version 2>/dev/null | head -n1 | sed -E 's/^[Qq]uickshell ([^ ]+).*/\\1/')"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = { gpu: [] };
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i < 0) continue;
                    const k = l.slice(0, i), v = l.slice(i + 1).trim();
                    if (k === "gpu") m.gpu.push(v.replace(/Corporation |Advanced Micro Devices, Inc\. |\[AMD\/ATI\] /g, ""));
                    else m[k] = v;
                }
                root.info = m;
            }
        }
    }
    // the AUR package manager: yay (install.sh installs it), otherwise paru, otherwise only pacman
    readonly property var rows: [
        ["device", info.model], ["system", info.os], ["kernel", info.kernel], ["processor", info.cpu ? `${info.cpu} · ${info.cores} threads` : ""],
        ["graphics", (info.gpu ?? []).join("  ·  ") + (info.nvidia ? `  ·  nvidia ${info.nvidia}` : "")],
        ["memory", info.mem ? `${info.mem} gb` : ""], ["storage", info.disk], ["bios", info.bios],
        ["hyprland", info.hypr], ["quickshell", info.qs]
    ].filter(r => r[1])

    // ---- updates: on the button and once on the first opening ----
    property var updates: []
    property string checked: ""
    property bool checking: false
    function check() {
        checking = true;
        upd.running = true;
    }
    onLiveChanged: if (live && !checked && !checking) check()
    Process {
        id: upd
        command: ["sh", "-c", "command -v checkupdates >/dev/null && checkupdates 2>/dev/null; a=$(command -v yay || command -v paru); [ -n \"$a\" ] && \"$a\" -Qua 2>/dev/null | sed 's/^/aur:/'; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.updates = text.split("\n").filter(Boolean);
                root.checked = Qt.formatTime(new Date(), "hh:mm");
                root.checking = false;
            }
        }
    }
    function update() {
        Quickshell.execDetached(["kitty", "--title", "updates", "sh", "-c",
            'a=$(command -v yay || command -v paru); if [ -n "$a" ]; then "$a" -Syu; else sudo pacman -Syu; fi; printf "\\ndone · press enter "; read -r _']);
    }

    Grid {
        columns: 2
        columnSpacing: 30
        rowSpacing: 12
        Repeater {
            model: [].concat(...root.rows)
            Text {
                required property string modelData
                required property int index
                width: index % 2 ? 760 : implicitWidth
                wrapMode: Text.Wrap
                text: modelData
                font { family: index % 2 ? Theme.ui : Theme.mono; pixelSize: index % 2 ? 17 : 11; capitalization: index % 2 ? Font.MixedCase : Font.AllUppercase; letterSpacing: index % 2 ? 0 : 1.5 }
                color: index % 2 ? Theme.fg : Theme.grey
            }
        }
    }

    Row {
        spacing: 20
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Lb { text: "updates" }
            Row {
                spacing: 12
                Num { id: un; text: root.checking && !root.checked ? "…" : root.updates.length; font.pixelSize: 64 }
                Lb { anchors.baseline: un.baseline; text: root.checking ? "checking…" : root.checked ? `checked ${root.checked}${root.updates.some(u => u.startsWith("aur:")) ? " · incl. aur" : ""}` : "" }
            }
        }
        Act { anchors.verticalCenter: parent.verticalCenter; icon: "\u{F0450}"; text: "check"; onHit: if (!root.checking) root.check() }
        Act { anchors.verticalCenter: parent.verticalCenter; visible: root.updates.length > 0; icon: "\u{F06B0}"; text: "update"; onHit: root.update() }
    }
    Flickable {
        visible: root.updates.length > 0
        width: 950
        height: Math.min(contentHeight, 150)
        contentHeight: ul.height
        clip: true
        Flow {
            id: ul
            width: parent.width
            spacing: 18
            Repeater {
                model: root.updates
                Lb { required property string modelData; text: modelData.replace(/^aur:/, "aur · ").split(" ").slice(0, 1).join(""); px: 10 }
            }
        }
    }
}
