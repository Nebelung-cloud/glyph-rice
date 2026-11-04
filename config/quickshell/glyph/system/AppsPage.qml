import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// default apps: on the left what the app is for, with the one set now; on the right everyone who says they can open it (MimeType= in their
// .desktop). One click sets it, at once and for all of the row's types. Hidden apps (NoDisplay) are listed only if they're already the choice
Page {
    id: root
    property bool live
    caption: `default apps · ${kinds[sel][0]}`

    // a row: the label and the types; the first type is the one asked about
    readonly property var kinds: [
        ["web browser", "x-scheme-handler/https x-scheme-handler/http text/html application/xhtml+xml"],
        ["files", "inode/directory"],
        ["email", "x-scheme-handler/mailto"],
        ["text", "text/plain"],
        ["images", "image/png image/jpeg image/gif image/webp image/bmp image/svg+xml image/tiff"],
        ["video", "video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo"],
        ["music", "audio/mpeg audio/flac audio/ogg audio/x-wav audio/mp4 audio/aac"],
        ["pdf", "application/pdf"],
        ["archives", "application/zip application/x-tar application/x-7z-compressed application/vnd.rar application/x-compressed-tar"]
    ]
    property int sel: 0
    property var desktop: [] // [{ file, name, hidden, types }]
    property var current: [] // per row, the file set now
    onLiveChanged: if (live) {
        scan.running = true;
        query.running = true;
    }

    // everything in one pass: reading each .desktop per row took seconds, and clicks felt dead until it finished. Your own
    // ~/.local/share/applications comes first and overrides a system file of the same name
    Process {
        id: scan
        command: ["bash", "-c", `dirs=("\${XDG_DATA_HOME:-$HOME/.local/share}/applications")
IFS=: read -ra sys <<< "\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "\${sys[@]}"; do dirs+=("$d/applications"); done
for d in "\${dirs[@]}"; do
  [ -d "$d" ] || continue
  find -L "$d" -maxdepth 1 -name '*.desktop' -exec awk '
    function out() { if (file && mime) { n = split(file, p, "/"); print p[n] "\\t" name "\\t" hide "\\t" mime } }
    FNR == 1 { out(); file = FILENAME; name = ""; hide = 0; mime = "" }
    /^Name=/ && !name { name = substr($0, 6) }
    /^(NoDisplay|Hidden)=true/ { hide = 1 }
    /^MimeType=/ { mime = substr($0, 10) }
    END { out() }' {} +
done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = [];
                for (const l of text.split("\n")) {
                    const [file, name, hide, mime] = l.split("\t");
                    if (!mime || seen[file]) continue;
                    seen[file] = true;
                    out.push({ file, name: name || file.replace(/\.desktop$/, ""), hidden: hide === "1", types: mime.split(";") });
                }
                root.desktop = out.sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }
    Process {
        id: query
        command: ["bash", "-c", 'for m in "$@"; do printf "%s\\n" "$(xdg-mime query default "$m" 2>/dev/null)"; done', "bash"].concat(kinds.map(k => k[1].split(" ")[0]))
        stdout: StdioCollector { onStreamFinished: root.current = text.split("\n").slice(0, root.kinds.length) }
    }

    readonly property var apps: {
        const types = kinds[sel][1].split(" "), cur = current[sel];
        const list = desktop.filter(a => a.file === cur || !a.hidden && a.types.some(t => types.includes(t)));
        // two «Google Chrome» (the package and the flatpak) — tell them apart by the file
        const n = {};
        list.forEach(a => n[a.name] = (n[a.name] ?? 0) + 1);
        return list.map(a => ({ file: a.file, name: n[a.name] > 1 ? `${a.name} · ${a.file.replace(/\.desktop$/, "")}` : a.name }));
    }
    function nameOf(i) {
        const f = current[i];
        return !f ? "not set" : desktop.find(a => a.file === f)?.name ?? f.replace(/\.desktop$/, "");
    }
    function set(file) {
        const c = current.slice();
        c[sel] = file;
        current = c;
        Quickshell.execDetached(["xdg-mime", "default", file].concat(kinds[sel][1].split(" ")));
    }

    Row {
        spacing: 40

        Column {
            width: 460
            spacing: 6
            Repeater {
                model: root.kinds
                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    width: parent.width
                    height: 62
                    radius: Theme.corner(31)
                    color: on ? Theme.fg : hov.hovered ? Theme.s3 : Theme.s2
                    border { width: activeFocus && !on ? 1 : 0; color: Theme.fg }
                    activeFocusOnTab: true
                    onActiveFocusChanged: if (activeFocus) root.sel = index
                    Keys.onPressed: e => {
                        if (e.key !== Qt.Key_Right && e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) return;
                        list.forceActiveFocus();
                        e.accepted = true;
                    }
                    Lb { x: 28; anchors.verticalCenter: parent.verticalCenter; text: row.modelData[0]; color: row.on ? Theme.ink : Theme.grey }
                    Text {
                        anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                        width: 230
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: root.nameOf(row.index)
                        font { family: Theme.ui; pixelSize: 16 }
                        color: row.on ? Theme.ink : Theme.fg
                    }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.sel = row.index }
                }
            }
        }

        Column {
            width: 500
            spacing: 10
            Lb { x: 8; text: root.apps.length ? `can open it · ${root.apps.length}` : "no installed app says it can open this" }
            ListView {
                id: list
                width: parent.width
                height: 570
                clip: true
                spacing: 6
                model: root.apps
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                keyNavigationEnabled: true
                Keys.onPressed: e => {
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
                    if (currentItem) root.set(currentItem.modelData.file);
                    e.accepted = true;
                }
                delegate: Rectangle {
                    id: app
                    required property var modelData
                    required property int index
                    readonly property bool on: root.current[root.sel] === modelData.file
                    width: ListView.view.width
                    height: 58
                    radius: Theme.corner(29)
                    color: pick.hovered || list.activeFocus && list.currentIndex === index ? Theme.s3 : Theme.s2
                    Text {
                        anchors { left: parent.left; leftMargin: 28; right: mark.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: app.modelData.name
                        font { family: Theme.ui; pixelSize: 17; weight: app.on ? Font.DemiBold : Font.Normal }
                        color: Theme.fg
                    }
                    Lb { id: mark; anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter } visible: app.on; text: "in use"; px: 10; color: Theme.fg }
                    HoverHandler { id: pick; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.set(app.modelData.file) }
                }
            }
        }
    }
}
