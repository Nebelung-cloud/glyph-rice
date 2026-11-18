import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.components
import "../prefs"

// about the system: model, system, kernel, processor, graphics (and the nvidia driver version), memory, disk, bios, hyprland, quickshell.
// Updates: checkupdates (pacman-contrib) and AUR via yay/paru — a count and a list; «update» opens kitty with the upgrade
Sheet {
    id: root
    property bool live
    caption: `about · ${info.host ?? ""}`

    property var info: ({})
    // started, not bound to live: leaving the page mid-probe killed it, and the half it had printed stayed for good
    Component.onCompleted: if (live) probe.running = true
    Process {
        id: probe
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
    readonly property var specs: [
        ["device", info.model], ["system", info.os], ["kernel", info.kernel], ["processor", info.cpu ? `${info.cpu} · ${info.cores} threads` : ""],
        ["graphics", (info.gpu ?? []).join("  ·  ") + (info.nvidia ? `  ·  nvidia ${info.nvidia}` : "")],
        ["memory", info.mem ? `${info.mem} gb` : ""], ["storage", info.disk], ["bios", info.bios],
        ["hyprland", info.hypr], ["quickshell", info.qs], ["login screen", login]
    ].filter(r => r[1])

    // ---- updates: on the button and once on the first opening ----
    property var updates: []
    property string checked: ""
    property bool checking: false
    function check() {
        checking = true;
        upd.running = true;
    }
    onLiveChanged: if (live) {
        if (!info.os) probe.running = true;
        if (!checked && !checking) check();
        riceCheck.running = true;
        loginCheck.running = true;
    }
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
    // ---- the rice's own updates: commits on GitHub this copy doesn't have. -1 — no answer: offline, or a copy that follows nothing ----
    property int riceNew: -1
    Process {
        id: riceCheck
        command: ["sh", "-c", 'r=$(git -C "$(readlink -f "$1")" rev-parse --show-toplevel) && git -C "$r" fetch -q && git -C "$r" rev-list --count "HEAD..@{u}"', "sh", Quickshell.shellPath("")]
        stdout: StdioCollector { onStreamFinished: root.riceNew = text.trim() === "" ? -1 : +text.trim() }
    }
    // System covers the screen and holds the keyboard: it has to leave, or the terminal opens unseen behind it. Pressed again while that
    // terminal is open — go to it: a second one prompts for sudo as well, and abandoned prompts count as failures and lock the account
    signal done
    function update() {
        const open = Hyprland.toplevels.values.find(t => t.title === "updates");
        if (open) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${open.address}" })`);
        else Quickshell.execDetached(["kitty", "--title", "updates", "bash", Quickshell.shellPath("system/update.sh")]);
        checked = ""; // count again on the next visit
        riceNew = -1;
        done();
    }
    // the login screen: which one now, and a terminal with the menu to change it
    property string login: ""
    Process {
        id: loginCheck
        command: ["sh", "-c", 'case "$(systemctl show -p Id --value display-manager.service)" in greetd*) grep -qs /dial/ /etc/greetd/config.toml && echo "dial greeter" || echo "lock greeter" ;; sddm*) echo "sddm" ;; display-manager*|"") echo "none" ;; *) systemctl show -p Id --value display-manager.service | sed "s/.service//" ;; esac']
        stdout: StdioCollector { onStreamFinished: root.login = text.trim() }
    }
    function changeLogin() {
        const open = Hyprland.toplevels.values.find(t => t.title === "login screen");
        if (open) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${open.address}" })`);
        else Quickshell.execDetached(["kitty", "--title", "login screen", "bash", "-c",
            'r=$(git -C "$(readlink -f "$1")" rev-parse --show-toplevel) && "$r/install.sh" --login-screen; printf "\\npress enter "; read -r _', "bash", Quickshell.shellPath("")]);
        done();
    }

    readonly property var what: ({
        device: "The computer's maker and model.", system: "The Linux distribution this runs on.",
        kernel: "The core of the system that talks to the hardware. Updates bring new drivers and fixes.",
        processor: "The CPU. Threads are how many tasks it can run at once.", graphics: "The graphics chips that draw the screen and run games.",
        memory: "RAM: room for open apps. More lets you keep more open at once.", storage: "Space used on the system drive, of its total.",
        bios: "The firmware that starts the computer, and its date. Updates come from the maker.",
        hyprland: "The compositor: it draws windows and handles input.", quickshell: "What this whole shell is built with.",
        "login screen": "What you see before logging in."
    })
    readonly property Component list: Component {
        Flow {
            width: 520
            spacing: 18
            Repeater {
                model: root.updates.slice(0, 60)
                Lb { required property string modelData; text: modelData.split(" ")[0].replace(/^aur:/, "aur · "); px: 10 }
            }
            Lb { visible: root.updates.length > 60; text: `+ ${root.updates.length - 60} more`; px: 10 }
        }
    }

    Lb { topPadding: 8; bottomPadding: 4; text: "this computer" }
    Repeater {
        model: root.specs
        Opt {
            required property var modelData
            title: modelData[0] === "bios" ? "BIOS" : modelData[0][0].toUpperCase() + modelData[0].slice(1)
            hint: modelData[1]
            about: `${root.what[modelData[0]] ?? ""} ${modelData[1]}`
            value: modelData[1].length <= 14 ? modelData[1] : ""
        }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: "updates" }
    Opt {
        title: "System updates"
        hint: root.checking ? "Checking…" : root.checked ? `Checked at ${root.checked}${root.updates.some(u => u.startsWith("aur:")) ? ", AUR included" : ""}.` : "Not checked yet."
        about: "Packages with a newer version. Updating often keeps you safe and avoids one huge update later."
        value: root.checking && !root.checked ? "…" : `${root.updates.length}`
        preview: root.list
        Act { icon: "\u{F0450}"; text: "check"; onHit: if (!root.checking) root.check() }
    }
    Opt {
        title: "The rice"
        hint: root.riceNew < 0 ? "Couldn't check for updates." : root.riceNew === 0 ? "Up to date." : `${root.riceNew} new ${root.riceNew === 1 ? "change" : "changes"} on GitHub.`
        about: "This shell's own updates, pulled from its git repository. They come with the update below."
        value: root.riceNew < 0 ? "?" : `${root.riceNew}`
    }
    Opt {
        visible: root.updates.length > 0 || root.riceNew > 0
        title: "Update everything"
        hint: "Opens a terminal that installs it all."
        about: "Asks for your password in the terminal. This panel closes so you can see it. Restart after a kernel update."
        value: `${root.updates.length + Math.max(0, root.riceNew)}`
        Act { icon: "\u{F06B0}"; text: "update"; onHit: root.update() }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: "more" }
    Opt {
        title: "Keyboard shortcuts"
        hint: "Show the welcome card with every shortcut."
        about: "The card from the first start. This panel closes to show it."
        value: ""
        Act { icon: "\u{F030C}"; text: "show"; onHit: { Theme.state.welcomed = false; root.done(); } }
    }
    Opt {
        title: "Login screen"
        hint: root.login ? `Now: ${root.login}.` : "What you see before logging in."
        about: "Opens a terminal with a menu to switch it. It asks for your password."
        value: root.login
        Act { icon: "\u{F0341}"; text: "change"; onHit: root.changeLogin() }
    }
}
