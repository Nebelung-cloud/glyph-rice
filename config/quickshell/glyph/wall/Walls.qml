import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// wallpapers: Super+Shift+W or settings → look. Not a grid of images — the whole screen is the preview: the selected one assembles in dots
// as a wave from the strip at the bottom. The strip — circle thumbnails in dots, the selected one in the center in a ring (it's lit by the fraction of the way through the collection),
// under the one live right now — a red dot. The first circle — NOTHING: no image, just the grid and orb.
// ←→ / the wheel — page through, tab — the look (dots / color dots / grey photo / color), g — glass, ↑↓ — the dot step, shift ↑↓ — brightness, ↵ or a click on
// the selected one — set it, esc — as it was. Images — from Theme.state.wallDir, screen-sized copies — in Theme.wallCache (once)
PanelWindow {
    id: root

    readonly property string dir: Theme.state.wallDir || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    // the looks in screen order; stored as Wall numbers (color dots came last — 3, the old numbers didn't shift)
    readonly property var looks: ["dots", "color dots", "mono", "color"]
    readonly property var lookIds: [0, 3, 1, 2]
    function stepLook(d) { look = lookIds[(lookIds.indexOf(look) + d + lookIds.length) % lookIds.length]; }
    // copies — in the screen's physical pixels, with spare room for cropping
    readonly property string res: {
        const s = Quickshell.screens[0];
        if (!s) return "2880x1800^";
        const d = s.devicePixelRatio; // a landscape copy even when the first screen is rotated. From SenulMapa/glyph-rice
        return `${Math.round(Math.max(s.width, s.height) * d)}x${Math.round(Math.min(s.width, s.height) * d)}^`;
    }

    property var files: [] // the originals that already have a copy, by name
    property var fresh: [] // what the current pass found
    readonly property var list: [""].concat(files)
    // the selected one — by path, the index — from it: while the cache is being written, new ones land in the middle and the strip doesn't shift
    property string pick: ""
    readonly property int sel: Math.max(0, list.indexOf(pick))
    property int look: 0
    property int pitch: 10
    property int bright: 85
    property bool glass: false
    property bool pulse: false // the wallpaper swells with the music; starts cava once set
    property bool hasCava: false
    Process { running: true; command: ["sh", "-c", "command -v cava"]; onExited: code => root.hasCava = code === 0 }
    property int rib: 28
    property int bend: 50

    function name(p) { return p ? p.slice(p.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "") : "nothing"; }
    function go(d) { pick = list[Math.max(0, Math.min(list.length - 1, sel + d))]; }

    // the preview — once the paging stops: every image is a decode and 20 MB of video memory, on fast scrolling that's stutters.
    // The strip moves at once
    property string view: ""
    onPickChanged: settle.restart()
    Timer { id: settle; interval: 160; onTriggered: root.view = root.pick }

    // the strip moves as one animation: pos catches up with sel, the circles compute their place from the fractional distance to it
    property real pos: sel
    Behavior on pos { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    // a circle at distance d: the selected 190, neighbours 128, further 12 less each, no less than 64; between whole numbers — linearly
    function size(d) { d = Math.abs(d); return d < 1 ? 190 - 62 * d : Math.max(64, 128 - (d - 1) * 12); }
    // circle centers at whole d, beyond 9 isn't needed — nothing's visible there anymore
    readonly property var at: {
        const a = [0];
        for (let k = 1; k <= 10; k++) a.push(a[k - 1] + (size(k - 1) + size(k)) / 2 + (k === 1 ? 44 : 22));
        return a;
    }
    function off(d) {
        const a = Math.min(Math.abs(d), 9), k = Math.floor(a), x = at[k] + (at[k + 1] - at[k]) * (a - k);
        return d < 0 ? -x : x;
    }

    property bool shown: false
    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: shown && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    Binding { target: Sys; property: "wallOpen"; value: root.visible }

    function open() {
        const s = Theme.state;
        pick = s.wall;
        view = s.wall;
        look = s.wallLook;
        pitch = s.wallPitch;
        bright = s.wallBright;
        glass = s.wallGlass;
        pulse = s.wallPulse;
        rib = s.wallRib;
        bend = s.wallBend;
        if (!scan.running) {
            fresh = [];
            scan.running = true;
        }
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function apply() {
        const s = Theme.state;
        s.wall = pick;
        s.wallLook = look;
        s.wallPitch = pitch;
        s.wallBright = bright;
        s.wallGlass = glass;
        s.wallPulse = pulse;
        s.wallRib = rib;
        s.wallBend = bend;
        close();
    }

    // screen-sized copies. One bash checks the fresh ones without a single process per file; missing or older than the original — magick, three
    // at a time (an 8k png eats hundreds of MB). A finished one — as a line on stdout. We write to a temp file and move it: an interrupted magick
    // won't leave a broken copy newer than the original
    Process {
        id: scan
        command: ["bash", "-c", `shopt -s nullglob nocaseglob; mkdir -p "$2"; todo=()
for f in "$1"/*.{jpg,jpeg,png,webp}; do
    if [ "$2/\${f##*/}.jpg" -nt "$f" ]; then printf '%s\\n' "$f"; else todo+=("$f"); fi
done
[ \${#todo[@]} -eq 0 ] || printf '%s\\0' "\${todo[@]}" | xargs -0 -P 3 -I{} sh -c 'b=$(basename "$1")
magick "$1[0]" -resize "$3" -quality 90 "$2/.$b.jpg" 2>/dev/null && mv "$2/.$b.jpg" "$2/$b.jpg" && printf "%s\\n" "$1"' _ {} "$2" "$3"`,
            "bash", root.dir, Theme.wallCache, root.res]
        stdout: SplitParser {
            onRead: f => {
                root.fresh.push(f);
                if (!root.files.includes(f)) root.files = root.files.concat([f]).sort();
            }
        }
        // the ones removed from the folder — out; unchanged — leave it: a new array would recreate the whole strip
        onExited: {
            const f = root.fresh.slice().sort();
            if (f.join("\n") !== root.files.join("\n")) root.files = f;
        }
    }

    visible: t > 0 || shown
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-wall"

    Stage {
        id: stage
        opacity: root.t
        focus: true
        Keys.onPressed: e => {
            const up = e.key === Qt.Key_Up, down = e.key === Qt.Key_Down;
            if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.go(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) root.go(1);
            else if (e.key === Qt.Key_Home) root.pick = "";
            else if (e.key === Qt.Key_Tab) root.stepLook(1);
            else if (e.key === Qt.Key_Backtab) root.stepLook(-1);
            else if (e.key === Qt.Key_G) root.glass = !root.glass;
            else if ((up || down) && e.modifiers & Qt.ShiftModifier) root.bright = Math.max(10, Math.min(100, root.bright + (up ? 5 : -5)));
            else if (up || down) root.pitch = Math.max(4, Math.min(32, root.pitch + (up ? 1 : -1)));
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        // the same as under the home wallpaper: the grid and orb — visible at NOTHING and in the wave toward it; the image covered it — don't draw
        Rectangle { anchors.fill: parent; color: Theme.bg }
        Image {
            visible: Theme.state.grid && !prev.item?.opaque
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }
        Orb { visible: Theme.state.orb && !prev.item?.opaque; x: stage.width - 720; y: stage.height - 580 }
        // the preview lives while the picker is visible: closed — the two screen-sized images are unloaded
        Loader {
            id: prev
            anchors.fill: parent
            active: root.visible
            sourceComponent: Wall {
                path: root.files.includes(root.view) ? Theme.wallSrc(root.view) : ""
                look: root.look
                pitch: root.pitch
                bright: root.bright / 100
                glass: root.glass
                rib: root.rib
                bend: root.bend / 100
                origin: Qt.point(width / 2, 850)
            }
        }

        // the wheel — page through; a click outside — take focus off the knobs
        MouseArea {
            anchors.fill: parent
            property real acc: 0
            onClicked: stage.forceActiveFocus()
            onWheel: w => {
                acc += w.angleDelta.y || w.angleDelta.x;
                while (Math.abs(acc) >= 120) {
                    root.go(acc > 0 ? -1 : 1);
                    acc -= Math.sign(acc) * 120;
                }
            }
        }

        // the labels must read over the image: the background fades away at the top and bottom
        Rectangle {
            width: parent.width
            height: 380
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.fade(Theme.bg, 0.85) }
                GradientStop { position: 1; color: Theme.fade(Theme.bg, 0) }
            }
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 460
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.fade(Theme.bg, 0) }
                GradientStop { position: 1; color: Theme.fade(Theme.bg, 0.9) }
            }
        }

        // the Doto number and the name
        Column {
            x: 150 - 30 * (1 - root.t)
            y: 110
            Lb { text: `wallpaper · ${root.files.length} in ${root.dir.replace(Quickshell.env("HOME"), "~")}` }
            Row {
                topPadding: 18
                spacing: 10
                Num { id: idx; text: String(root.sel).padStart(2, "0"); font.pixelSize: 150 }
                Num { anchors.baseline: idx.baseline; text: "/" + String(root.list.length - 1).padStart(2, "0"); font.pixelSize: 54; color: Theme.mute }
            }
            Lb { topPadding: 22; width: 700; elide: Text.ElideRight; text: root.name(root.pick); px: 14; color: Theme.fg }
        }

        // the look and the knobs
        Column {
            anchors { right: parent.right; rightMargin: 150 - 30 * (1 - root.t) }
            y: 110
            spacing: 30
            Pick { anchors.right: parent.right; label: "look"; opts: root.looks; cur: root.lookIds.indexOf(root.look); onPicked: i => root.look = root.lookIds[i] }
            Pick { visible: root.hasCava; anchors.right: parent.right; label: "beat"; opts: ["still", "music"]; cur: root.pulse ? 1 : 0; onPicked: i => root.pulse = i === 1 }
            Row {
                anchors.right: parent.right
                spacing: 36
                Dial { size: 120; label: "dot · px"; from: 4; to: 32; live: true; value: root.pitch; onMoved: v => root.pitch = v }
                Dial { size: 120; label: "light · %"; from: 10; to: 100; step: 5; live: true; value: root.bright; onMoved: v => root.bright = v }
            }
            // glass: a toggle, the rib width and bend; turned off — the rings are paler, but they still turn
            Row {
                anchors.right: parent.right
                spacing: 36
                Toggle { anchors.verticalCenter: parent.verticalCenter; width: 160; text: "glass"; on: root.glass; onFlip: root.glass = !root.glass }
                Dial { opacity: root.glass ? 1 : 0.4; size: 120; label: "rib · px"; from: 8; to: 80; step: 2; live: true; value: root.rib; onMoved: v => root.rib = v }
                Dial { opacity: root.glass ? 1 : 0.4; size: 120; label: "bend · %"; from: 0; to: 100; step: 5; live: true; value: root.bend; onMoved: v => root.bend = v }
            }
        }

        // the strip. The selected one is always in the center — the ring stands still, the circles move under it. Circles of one size 190, shrunk by scale:
        // the dot layer (Art) is drawn once, while changing width would redraw it every frame for all fifteen
        Ring {
            x: stage.width / 2 - width / 2
            y: 850 - height / 2
            width: root.size(0) + 36
            height: width
            n: 60
            dot: 4
            f: root.list.length > 1 ? root.sel / (root.list.length - 1) : 0
        }
        Repeater {
            model: root.list
            Item {
                id: th
                required property string modelData
                required property int index
                readonly property real d: index - root.pos
                visible: Math.abs(d) < 7.5
                x: stage.width / 2 + root.off(d) - 95
                y: 850 - 95
                width: 190
                height: 190
                scale: root.size(d) / 190
                opacity: 1 - Math.abs(d) * 0.12

                Loader {
                    anchors.fill: parent
                    active: th.visible && !!th.modelData
                    sourceComponent: Art { url: "file://" + Theme.wallSrc(th.modelData).split("/").map(encodeURIComponent).join("/"); step: 6 }
                }
                Rectangle {
                    visible: !th.modelData
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.bg
                    border { width: 1; color: Theme.s3 }
                    Lb { anchors.centerIn: parent; text: "nothing" }
                }
                // live right now
                Rectangle {
                    visible: th.modelData === Theme.state.wall
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: th.index === root.sel ? 36 : 22 }
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.accent
                }
                TapHandler {
                    onTapped: {
                        if (th.index === root.sel) root.apply();
                        else root.pick = th.modelData;
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
            spacing: 34
            Lb { text: "←→ browse" }
            Lb { text: "tab look" }
            Lb { text: "g glass" }
            Lb { text: "↑↓ dot size" }
            Lb { text: "shift ↑↓ light" }
            Lb { text: "↵ set" }
            Lb { text: "esc back"; TapHandler { onTapped: root.close() } }
        }
    }
}
