import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// clipboard: a panel from the launcher family, only wider — cliphist history as rows on the left, the selected entry in full on the right.
// A search pill with a red caret, filters as chips (Tab): all / text / links / images. Type — a glyph in a circle, an image —
// a thumbnail in dots, a color — the color itself. The selected row — a white pill. ⏎ — to the clipboard, you paste with Ctrl+V
PanelWindow {
    id: root

    readonly property var types: ({
        code: "\u{F0169}", text: "\u{F09A8}", link: "\u{F0337}", image: "\u{F02E9}", color: "\u{F03D8}", file: "\u{F0214}"
    })
    readonly property var filters: ["all", "text", "links", "images"]
    // ponytail: the image cache is shared with demonshot — the same files in XDG_RUNTIME_DIR, cleaned on session exit
    readonly property string cache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/demonshot-clip-"

    property var entries: [] // { id, text, type }
    property var held: []
    property int filter: 0
    property int sel: 0
    property var cached: ({}) // ids of images already in the cache
    readonly property string query: input.text.toLowerCase()

    readonly property var view: entries.filter(e =>
        (filter === 0 || filter === 2 && e.type === "link" || filter === 3 && e.type === "image"
            || filter === 1 && e.type !== "link" && e.type !== "image")
        && e.text.toLowerCase().includes(query))
    readonly property var cur: view[sel] ?? null
    // the full content of the selected entry; until it arrives — the preview from the list
    property string full: ""
    property string fullId: ""
    property string decId: ""
    readonly property string body: cur && fullId === cur.id ? full : cur?.text ?? ""

    function kind(t) {
        if (/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) \d+x\d+ \]\]$/.test(t)) return "image";
        if (t.startsWith("[[ binary data")) return "file";
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t)) return "color";
        if (/^https?:\/\/\S+$/.test(t)) return "link";
        if (/^(file:\/\/|~?\/)\S+$/.test(t)) return "file";
        // ponytail: code is guessed by brackets and familiar commands; a miss — shown as text
        if (/[{};]|^(sudo|git|cd|qs|hyprctl|pacman|paru|yay|npm|cargo|systemctl|sh|bash|curl) /.test(t)) return "code";
        return "text";
    }
    // image: [size, format, width, height] from «[[ binary data 340 KiB png 1920x1080 ]]»
    function img(e) { return e?.text.match(/binary data (.+) (\w+) (\d+)x(\d+) \]\]$/)?.slice(1) ?? ["", "", 0, 0]; }
    // css #RRGGBBAA → qt #AARRGGBB
    function rgb(s) { s = s.trim(); return s.length === 9 ? "#" + s.slice(7) + s.slice(1, 7) : s; }

    property bool shown: false
    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: shown && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function open() {
        list.running = true;
        input.text = "";
        filter = 0;
        sel = 0;
        shown = true;
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function move(d) { if (view.length) sel = Math.max(0, Math.min(sel + d, view.length - 1)); }

    function fire() {
        if (!cur) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", cur.id]);
        close();
    }
    // ponytail: pinning only protects from deletion; cliphist's max-items will still push out old entries
    function hold() {
        const id = cur?.id;
        if (!id) return;
        held = held.includes(id) ? held.filter(h => h !== id) : [...held, id];
        heldFile.setText(held.join("\n"));
    }
    function burn() {
        const it = cur;
        if (!it || held.includes(it.id)) return;
        del.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", it.id]);
    }

    onQueryChanged: sel = 0
    onFilterChanged: sel = 0
    onViewChanged: sel = Math.max(0, Math.min(sel, view.length - 1))
    onSelChanged: rows.positionViewAtIndex(sel, ListView.Contain)
    onCurChanged: if (cur) decode.restart()
    onVisibleChanged: if (visible) input.forceActiveFocus()

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const t = l.slice(l.indexOf("\t") + 1);
                    return { id: l.slice(0, l.indexOf("\t")), text: t, type: root.kind(t) };
                });
            }
        }
    }
    Process { id: del; onExited: list.running = true }
    Process {
        id: dec
        stdout: StdioCollector { onStreamFinished: { root.full = text; root.fullId = root.decId; } }
    }
    // the arrow is held — don't poke cliphist on every row. Binary isn't decoded: the row caches images, the rest is junk
    Timer {
        id: decode
        interval: 80
        onTriggered: {
            if (!root.cur || root.cur.text.startsWith("[[ binary data")) return;
            root.decId = root.cur.id;
            dec.exec(["sh", "-c", 'cliphist decode "$1" | head -c 4000', "sh", root.cur.id]);
        }
    }
    FileView {
        id: heldFile
        path: Quickshell.statePath("clip-held")
        printErrors: false
        onLoaded: root.held = text().split("\n").filter(l => l)
    }

    visible: t > 0 || shown
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-clip"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 140 + 24 * (1 - root.t)
            width: 1120
            height: Math.min(stage.height - 280, 760)
            opacity: root.t
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            // search: a pill, a red caret, filter chips — like the launcher
            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: 33
                color: Theme.s2

                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    focus: true
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Theme.ui; pixelSize: 22 }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.red
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 6
                        text: "Search clipboard"
                        font: input.font
                        color: Theme.mute
                    }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                        else if (e.key === Qt.Key_Tab) root.filter = (root.filter + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.filter = (root.filter + 3) % 4;
                        else if (e.key === Qt.Key_Down || ctrl && e.key === Qt.Key_J) root.move(1);
                        else if (e.key === Qt.Key_Up || ctrl && e.key === Qt.Key_K) root.move(-1);
                        else if (ctrl && e.key === Qt.Key_P) root.hold();
                        else if (e.key === Qt.Key_Delete) root.burn();
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.filters
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.filter === index ? Theme.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.filter === parent.index ? Theme.ink : Theme.grey }
                            TapHandler { onTapped: { root.filter = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            Row {
                id: head
                x: 42
                y: search.y + search.height + 30
                spacing: 14
                Num { anchors.baseline: hlab.baseline; text: root.view.length; font.pixelSize: 34 }
                Lb { id: hlab; text: root.view.length === 1 ? "entry" : "entries" }
            }

            ListView {
                id: rows
                anchors { left: parent.left; leftMargin: 34; top: head.bottom; topMargin: 18; bottom: parent.bottom; bottomMargin: 34 }
                width: 500
                clip: true
                spacing: 4
                model: root.view
                boundsBehavior: Flickable.StopAtBounds
                delegate: Entry {}
            }

            // the selected entry in full
            Rectangle {
                id: card
                anchors { left: rows.right; leftMargin: 24; right: parent.right; rightMargin: 34; top: head.top; bottom: parent.bottom; bottomMargin: 34 }
                radius: 40
                color: Theme.s2

                Lb { id: kindLb; x: 30; y: 30; text: root.cur ? `${root.cur.type} · ${root.sel + 1} of ${root.view.length}` : "" }
                Row {
                    anchors { right: parent.right; rightMargin: 30; verticalCenter: kindLb.verticalCenter }
                    visible: !!root.cur && root.held.includes(root.cur.id)
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F0403}"; font.pixelSize: 15 }
                    Lb { text: "pinned"; color: Theme.fg }
                }
                Loader {
                    anchors { left: parent.left; right: parent.right; top: kindLb.bottom; bottom: parent.bottom; margins: 30; topMargin: 26 }
                    clip: true
                    sourceComponent: root.cur ? ({ text: textPv, code: codePv, link: linkPv, color: colorPv, image: imagePv, file: filePv })[root.cur.type] : emptyPv
                }
            }

            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 28 }
                spacing: 34
                Repeater {
                    model: ["↑↓ select", "↵ copy", "tab filter", "^p pin", "del delete", "esc close"]
                    Lb { required property string modelData; text: modelData }
                }
            }
        }
    }

    // a history row: a 48 circle (glyph / dot thumbnail / the color itself), the text in one line, a Doto number on the right.
    // The selected one — a white pill, black text
    component Entry: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property string type: modelData.type
        readonly property var m: type === "image" ? root.img(modelData) : null
        readonly property bool on: root.sel === index
        width: rows.width
        height: 64
        radius: 32
        color: on ? Theme.fg : "transparent"

        Rectangle {
            id: dot
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            radius: 24
            color: row.type === "color" ? root.rgb(row.modelData.text) : row.on ? Theme.ink : Theme.s2
            border { width: row.type === "color" ? 1 : 0; color: Theme.s3 }
            Icon {
                anchors.centerIn: parent
                visible: row.type !== "image" && row.type !== "color"
                text: root.types[row.type]
                font.pixelSize: 22
            }
            Art {
                anchors.fill: parent
                visible: row.type === "image"
                step: 3
                url: root.cached[row.modelData.id] ? "file://" + root.cache + row.modelData.id : ""
            }
        }
        // the image — into the cache when the row first appears: the whole history at once — hundreds of MB in tmpfs.
        // Via a temporary file, so the preview doesn't grab a half-written one
        Process {
            running: row.type === "image" && !root.cached[row.modelData.id]
            command: ["sh", "-c", 'f="$1$2"; [ -s "$f" ] || { cliphist decode "$2" > "$f.$$" && mv "$f.$$" "$f"; }', "sh", root.cache, row.modelData.id]
            onExited: code => { if (!code) root.cached = Object.assign({}, root.cached, { [row.modelData.id]: true }); }
        }
        Column {
            anchors { left: dot.right; leftMargin: 14; right: tail.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 3
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: row.m ? `${row.m[2]}×${row.m[3]}` : row.modelData.text.replace(/\s+/g, " ").trim()
                font { family: Theme.ui; pixelSize: 15; weight: Font.Medium }
                color: row.on ? Theme.ink : Theme.fg
            }
            Lb {
                text: row.m ? `image · ${row.m[1]} · ${row.m[0]}` : row.type
                px: 10
                color: row.on ? Theme.ink : Theme.grey
                opacity: row.on ? 0.6 : 1
            }
        }
        Row {
            id: tail
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 12
            Icon { anchors.verticalCenter: parent.verticalCenter; visible: root.held.includes(row.modelData.id); text: "\u{F0403}"; font.pixelSize: 16; color: row.on ? Theme.ink : Theme.fg }
            Num { anchors.verticalCenter: parent.verticalCenter; text: String(row.index + 1).padStart(2, "0"); font.pixelSize: 26; color: row.on ? Theme.ink : Theme.mute }
        }
        // a click — select, on the selected one — copy
        TapHandler {
            onTapped: {
                if (row.on) root.fire();
                else root.sel = row.index;
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // ---- previews by type: the Loader stretches them over the card. Clipboard content — only PlainText: there can be html ----
    Component {
        id: textPv
        Text {
            text: root.body.trim()
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            font { family: Theme.ui; pixelSize: 26; weight: Font.Light }
            lineHeight: 1.2
            color: Theme.fg
        }
    }
    Component {
        id: codePv
        // ponytail: long lines are simply cut off by the card edge
        Text {
            text: root.body.replace(/\s+$/, "")
            textFormat: Text.PlainText
            font { family: Theme.mono; pixelSize: 14 }
            lineHeight: 1.6
            color: Theme.fg
        }
    }
    Component {
        id: linkPv
        Column {
            spacing: 14
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.body.match(/^\w+:\/\/([^\/?#]+)/)?.[1] ?? root.body
                font { family: Theme.ui; pixelSize: 44; weight: Font.Medium; letterSpacing: -0.88 }
                color: Theme.fg
            }
            Mono { text: root.body.trim() }
        }
    }
    Component {
        id: colorPv
        Column {
            readonly property color c: root.rgb(root.body)
            spacing: 28
            Rectangle { width: 200; height: 200; radius: 100; color: parent.c; border { width: 1; color: Theme.s3 } }
            Num { textFormat: Text.PlainText; text: root.body.trim().toUpperCase(); font.pixelSize: 64 }
            Lb { text: `rgb ${[parent.c.r, parent.c.g, parent.c.b].map(v => Math.round(v * 255)).join(" ")}` }
        }
    }
    Component {
        id: imagePv
        // the image in dots, like covers: monochrome, step 3
        Column {
            id: ipv
            readonly property var m: root.img(root.cur)
            spacing: 22
            Image {
                width: parent.width
                height: parent.height - dims.height - parent.spacing
                source: root.cached[root.cur?.id] ? "file://" + root.cache + root.cur.id : ""
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                asynchronous: true
                layer.enabled: true
                layer.effect: Dm { step: 3 }
            }
            Row {
                id: dims
                spacing: 14
                Num { anchors.baseline: dlab.baseline; text: `${ipv.m[2]}×${ipv.m[3]}`; font.pixelSize: 34 }
                Lb { id: dlab; text: `${ipv.m[1]} · ${ipv.m[0]}` }
            }
        }
    }
    Component {
        id: filePv
        Column {
            spacing: 20
            Rectangle {
                width: 96
                height: 96
                radius: 48
                color: Theme.s3
                Icon { anchors.centerIn: parent; text: root.types.file; font.pixelSize: 40 }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.body.trim().replace(/\/$/, "").split("/").pop()
                font { family: Theme.ui; pixelSize: 34; weight: Font.Medium; letterSpacing: -0.68 }
                color: Theme.fg
            }
            Mono { text: root.body.trim() }
        }
    }
    Component {
        id: emptyPv
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 18
                Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "\u{F014C}"; font.pixelSize: 48; color: Theme.mute }
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.entries.length ? "no matches" : "clipboard is empty" }
            }
        }
    }

    // the full path / address small under the large name
    component Mono: Text {
        width: parent?.width ?? 0
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 8
        elide: Text.ElideRight
        font { family: Theme.mono; pixelSize: 14 }
        lineHeight: 1.5
        color: Theme.grey
    }
}
