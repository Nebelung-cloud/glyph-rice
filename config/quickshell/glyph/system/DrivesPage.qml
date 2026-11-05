import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import "../prefs"

// drives: what's plugged in and the disks that aren't part of the system. Pick one to mount, open or safely remove it. Mounting goes through
// udisks like a file manager's: your own drives need no password, internal ones ask (the Auth card). New external drives mount by themselves
// through udiskie (shell.qml) unless that's turned off here
Page {
    id: root
    property bool live
    signal done // opened a folder: System gets out of the way
    caption: `drives · ${drives.length ? drives.length + " found" : "none found"}`

    property var drives: [] // [{ path, name, size, fs, mount, external, encrypted }]
    property string cur: "" // the selected one's path
    readonly property var drive: drives.find(d => d.path === cur) ?? null
    property string msg: ""
    function back() {
        if (!cur) return false;
        cur = "";
        return true;
    }

    // not shown: the running system's own mounts, swap, and the partitions no one opens
    function listed(p) {
        if (!p.fstype || /swap|LVM|linux_raid|zfs_member/i.test(p.fstype)) return false;
        const m = p.mountpoints.filter(Boolean);
        if (m.some(x => x === "/" || /^\/(boot|efi|home|var|usr|srv|root|opt|nix|tmp)(\/|$)/.test(x) || x === "[SWAP]")) return false;
        return !/EFI|Microsoft reserved|Windows recovery|BIOS boot/i.test(p.parttypename ?? "");
    }
    function flat(list, inherited) {
        return list.reduce((out, d) => {
            const external = inherited || d.rm || d.hotplug;
            return out.concat(listed(d) ? [{ path: d.path, name: d.label || d.model || d.name, size: d.size, fs: d.fstype, mount: d.mountpoints.filter(Boolean)[0] ?? "", external, encrypted: d.fstype === "crypto_LUKS" }] : [], flat(d.children ?? [], external));
        }, []);
    }
    Process {
        id: scan
        command: ["lsblk", "-J", "-o", "NAME,PATH,LABEL,SIZE,FSTYPE,MOUNTPOINTS,RM,HOTPLUG,MODEL,PARTTYPENAME"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.drives = root.flat(JSON.parse(text).blockdevices, false); } catch (e) { root.drives = []; }
            }
        }
    }
    onLiveChanged: if (live) scan.running = true
    Timer { running: root.live; interval: 3000; repeat: true; onTriggered: scan.running = true }

    Process {
        id: act
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            root.msg = code === 0 ? "" : (actErr.text.trim().split("\n").pop() || "it didn't work").replace(/^.*GDBus\.Error:[^:]*: /, "").replace(/^Error [^:]*: /, "");
            scan.running = true;
        }
    }
    function run(args) {
        msg = "";
        act.command = args;
        act.running = true;
    }
    function open(d) {
        Quickshell.execDetached(["xdg-open", d.mount]);
        done();
    }

    Row {
        spacing: 50

        Column {
            width: 520
            spacing: 4
            Lb { x: 8; bottomPadding: 6; text: root.drives.length ? "plugged in and spare disks" : "nothing to show · plug in a drive" }
            Repeater {
                model: root.drives
                Line {
                    required property var modelData
                    icon: modelData.external ? "\u{F11B0}" : "\u{F02CA}"
                    title: modelData.name
                    on: !!modelData.mount
                    picked: root.cur === modelData.path
                    sub: [modelData.size, modelData.fs, modelData.mount ? `open at ${modelData.mount}` : "not mounted", modelData.external ? "" : "internal"].filter(Boolean).join(" · ")
                    onHit: { root.msg = ""; root.cur = modelData.path; }
                }
            }
            Item { width: 1; height: 16 }
            Toggle { text: "mount new drives by themselves"; on: Theme.state.autoMount; onFlip: Theme.state.autoMount = !Theme.state.autoMount }
        }

        Column {
            width: 470
            spacing: 16
            Lb { visible: !root.drive && root.drives.length > 0; text: "pick a drive" }
            Column {
                visible: !!root.drive
                spacing: 16
                width: parent.width
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.drive?.name ?? ""
                    font { family: Theme.ui; pixelSize: 26 }
                    color: Theme.fg
                }
                Lb { text: root.drive ? `${root.drive.path} · ${root.drive.size} · ${root.drive.fs}` : "" }
                Lb {
                    visible: root.drive?.encrypted ?? false
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "encrypted · open it in the file manager, which asks for its passphrase"
                }
                Row {
                    spacing: 14
                    Act {
                        visible: !!root.drive && !root.drive.mount && !root.drive.encrypted
                        icon: "\u{F0450}"
                        text: "mount"
                        onHit: root.run(["udisksctl", "mount", "-b", root.drive.path])
                    }
                    Act {
                        visible: !!root.drive?.mount
                        icon: "\u{F024B}"
                        text: "open"
                        onHit: root.open(root.drive)
                    }
                    Act {
                        visible: !!root.drive?.mount
                        icon: "\u{F0156}"
                        text: root.drive?.external ? "safely remove" : "unmount"
                        onHit: root.run(["udisksctl", "unmount", "-b", root.drive.path])
                    }
                }
                Lb {
                    visible: !!root.drive?.mount && root.drive?.external
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "safely remove first, then unplug it when it says not mounted"
                }
                Lb { visible: !!root.msg; width: parent.width; wrapMode: Text.Wrap; text: root.msg; color: Theme.red }
            }
        }
    }
}
