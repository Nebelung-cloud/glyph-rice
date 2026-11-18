import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import "../prefs"

// drives: what's plugged in and the disks that aren't part of the system. Pick one to mount, open or safely remove it. Mounting goes through
// udisks like a file manager's: your own drives need no password, internal ones ask (the Auth card). New external drives mount by themselves
// through udiskie (shell.qml) unless that's turned off here
Sheet {
    id: root
    property bool live
    signal done // opened a folder: System gets out of the way
    caption: `drives · ${drives.length ? drives.length + " found" : "none found"}`

    property var drives: [] // [{ path, name, size, fs, mount, external, encrypted }]
    property string msg: ""
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
                // only on a change: a new list rebuilds the rows and drops the keyboard focus
                let n = [];
                try { n = root.flat(JSON.parse(text).blockdevices, false); } catch (e) {}
                if (JSON.stringify(n) !== JSON.stringify(root.drives)) root.drives = n;
            }
        }
    }
    onLiveChanged: if (live) {
        scan.running = true;
        kernelCheck.running = true;
    }
    Timer { running: root.live; interval: 3000; repeat: true; onTriggered: scan.running = true }

    // a kernel update removes the running kernel's modules until you restart, so a USB drive shows up to nothing: no driver can load for it
    property bool needsReboot: false
    Process {
        id: kernelCheck
        command: ["sh", "-c", '[ -d "/usr/lib/modules/$(uname -r)" ]']
        onExited: code => root.needsReboot = code !== 0
    }

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

    // the inspector for the drive whose row is shown: what it is, mount / open / remove. → on the row enters it
    readonly property var drive: hot?.modelData?.path !== undefined ? hot.modelData : null
    readonly property Component card: Component {
        Column {
            width: 470
            spacing: 16
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

    Lb {
        visible: root.needsReboot
        width: 620
        topPadding: 8
        wrapMode: Text.Wrap
        color: Theme.red
        text: "restart needed · the kernel was updated, so newly plugged USB drives won't appear until you restart"
    }
    Lb { topPadding: 8; bottomPadding: 4; text: root.drives.length ? "plugged in and spare disks · → for actions" : "nothing to show · plug in a drive" }
    Repeater {
        model: root.drives
        Opt {
            required property var modelData
            title: modelData.name
            hint: [modelData.size, modelData.fs, modelData.mount ? `open at ${modelData.mount}` : "not mounted", modelData.external ? "" : "internal"].filter(Boolean).join(" · ")
            about: modelData.external ? "A drive you plugged in. Mount it to use its files; safely remove it before unplugging so nothing gets lost."
                : "A disk inside the computer that the system itself doesn't use. Mounting it may ask for your password."
            value: modelData.mount ? "mounted" : "not mounted"
            preview: root.card
        }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: "new drives" }
    Opt {
        title: "Mount by themselves"
        hint: "Plugged-in drives open up without asking."
        about: "Off, a new drive just shows up here and waits for you to mount it."
        value: Theme.state.autoMount ? "on" : "off"
        Switch { on: Theme.state.autoMount; onFlip: Theme.state.autoMount = !Theme.state.autoMount }
    }
}
