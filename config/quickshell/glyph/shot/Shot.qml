import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// screenshot: the screen freezes (grim to a file, the frame under the overlay) and dims; the region — a 1px white frame with dots at the corners
// and the size in Doto, a magnifier at the cursor — the pixels as dots in a circle and the color. Modes — chips in a pill at the bottom.
// The shot: the frame flashes white (recording — red), the shot is already on the clipboard and in the folder, a card in the corner; a click — edit (Editor)
Scope {
    id: root

    readonly property var modes: ["region", "window", "screen", "record"]
    readonly property var delays: [0, 3, 13]
    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    property int mode: 0
    property int delay: 0
    property string frozen: ""
    property var scr: null
    // everything below — in layout pixels (Stage); logical = × Theme.s, the frame's — × k
    property var wins: []       // the current ws's windows: { x, y, w, h }
    property rect drag: Qt.rect(0, 0, 0, 0) // w = 0 — nothing selected
    property real mx: 0
    property real my: 0
    readonly property var hover: wins.find(w => mx >= w.x && mx < w.x + w.w && my >= w.y && my < w.y + w.h) ?? null
    readonly property rect sel: mode === 2 ? Qt.rect(0, 0, stage.width, stage.height)
        : mode === 1 ? (hover ? Qt.rect(hover.x, hover.y, hover.w, hover.h) : Qt.rect(0, 0, 0, 0))
        : drag
    readonly property real k: frozenImg.sourceSize.width / Math.max(1, stage.width)

    // the last shot: for the flash and the card
    property string shot: ""
    property string shotWhat: ""
    property string shotDims: ""
    property rect shotRect
    property bool shotRec: false

    function open() {
        if (aim.visible) return;
        const mon = Hyprland.focusedMonitor;
        scr = Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0];
        Hyprland.refreshToplevels();
        picker.unloadImage(frozenImg.source); // the canvas holds the frame in memory until we unload it
        freeze.next = `${run}/glyph-frozen-${Date.now()}.ppm`; // ponytail: uncompressed ppm — grim 90 ms versus 450 for png
        freeze.exec(["sh", "-c", 'rm -f "$3"/glyph-frozen-*; grim -t ppm -o "$1" "$2" && echo ok', "sh", scr.name, freeze.next, run]);
    }
    function close() { aim.shown = false; }

    function fire() {
        const r = sel.width > 2 && sel.height > 2 ? sel : Qt.rect(0, 0, stage.width, stage.height);
        const full = r.width === stage.width && r.height === stage.height;
        const s = Theme.s, w = Math.round(r.width * s), h = Math.round(r.height * s);
        const x = Math.round(scr.x + r.x * s), y = Math.round(scr.y + r.y * s);
        shotRect = r;
        shotRec = mode === 3;
        shotWhat = `${modes[mode]} · ${Qt.formatTime(new Date(), "hh:mm")}`;
        shotDims = `${w}×${h}`;
        // the overlay fades at once, without animation: recording and a timed shot use the live screen
        aim.snap = true;
        aim.shown = false;
        if (shotRec) {
            const g = full ? `-w ${scr.name}` : `-w region -region ${w}x${h}+${x}+${y}`;
            Quickshell.execDetached(["sh", "-c", `sleep ${delay}; notify-send -a "shot · rec" "Recording." "ctrl+alt+r — stop"; `
                + `gpu-screen-recorder ${g} ${Sys.recArgs()} -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"`]);
            return fx.restart();
        }
        // without a timer we crop the frozen frame — what you saw is what you got; with a timer we shoot the live screen
        // vips, unlike magick, fails on a frame one pixel past the frame's edge — a fractional scale, so we clamp
        const cx = Math.round(r.x * k), cy = Math.round(r.y * k);
        const crop = `${cx} ${cy} ${Math.min(Math.round(r.width * k), frozenImg.sourceSize.width - cx)} ${Math.min(Math.round(r.height * k), frozenImg.sourceSize.height - cy)}`;
        take.exec(["sh", "-c", `d="$(xdg-user-dir PICTURES)/shots"; mkdir -p "$d"; f="$d/shot-$(date +%F_%H-%M-%S).png"
            if [ "$1" = 0 ]; then vips crop "$4" "$f[compression=1]" $2 2>/dev/null; else sleep "$1"; grim -g "$3" "$f"; fi \
                && wl-copy -t image/png < "$f" && printf '%s' "$f"`,
            "sh", String(delay), crop, `${x},${y} ${w}x${h}`, frozen]);
    }

    Process {
        id: freeze
        property string next
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                root.frozen = freeze.next; // only now: the file is fully written
                root.mode = 0;
                root.drag = Qt.rect(0, 0, 0, 0);
                const s = Theme.s;
                root.wins = Hyprland.toplevels.values
                    .filter(t => t.workspace?.id === Hyprland.focusedMonitor?.activeWorkspace?.id && t.lastIpcObject?.size)
                    .sort((a, b) => (b.lastIpcObject.floating ?? false) - (a.lastIpcObject.floating ?? false)) // floating ones on top
                    .map(t => ({ x: (t.lastIpcObject.at[0] - root.scr.x) / s, y: (t.lastIpcObject.at[1] - root.scr.y) / s,
                                 w: t.lastIpcObject.size[0] / s, h: t.lastIpcObject.size[1] / s }));
                aim.snap = false;
                aim.shown = true;
                stage.forceActiveFocus();
            }
        }
    }
    Process {
        id: take
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                root.shot = text;
                fx.restart();
            }
        }
    }

    Editor { id: editor }

    // ============ viewfinder ============
    PanelWindow {
        id: aim

        // t: 0 → 1 over Theme.t. The frame opens at once (it matches the screen anyway), fades out entirely; snap — without animation
        property bool shown: false
        property bool snap: false
        property real t: shown ? 1 : 0
        Behavior on t { enabled: !aim.snap; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

        screen: root.scr
        visible: t > 0
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "glyph-shot"

        Stage {
            id: stage
            opacity: aim.shown ? 1 : aim.t
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                else if (e.key === Qt.Key_Space) root.mode = 1;
                else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                else if (e.key === Qt.Key_T) root.delay = (root.delay + 1) % 3;
                else return;
                e.accepted = true;
            }

            Image {
                id: frozenImg
                anchors.fill: parent
                source: root.frozen ? "file://" + root.frozen : "" // the cache is shared with the magnifier and the color picker: the frame decodes once, not three times
            }

            // everything outside the frame dims; while there's no frame — dims slightly
            Item {
                anchors.fill: parent
                opacity: aim.t
                readonly property color c: Theme.fade(Theme.bg, root.sel.width ? 0.74 : 0.35)
                readonly property rect r: root.sel.width ? root.sel : Qt.rect(0, 0, 0, 0)
                Rectangle { width: parent.width; height: parent.r.y; color: parent.c }
                Rectangle { y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: parent.c }
                Rectangle { y: parent.r.y; width: parent.r.x; height: parent.r.height; color: parent.c }
                Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: parent.c }
            }

            // the crosshair — a dotted line across the whole screen
            Dots { y: Math.round(root.my) - 4; width: parent.width; height: 8; opacity: 0.5 * aim.t }
            Dots { x: Math.round(root.mx) - 4; width: 8; height: parent.height; opacity: 0.5 * aim.t }

            // the frame: 1px White, thirds as dots, dots at the corners; the mode and size above it
            Item {
                id: vf
                visible: root.sel.width > 0
                opacity: aim.t
                x: root.sel.x
                y: root.sel.y
                width: root.sel.width
                height: root.sel.height

                Rectangle { anchors.fill: parent; color: "transparent"; border { width: 1; color: Theme.fg } }
                Repeater {
                    model: 2
                    Item {
                        required property int index
                        anchors.fill: parent
                        Dots { x: parent.width * (index + 1) / 3 - 4; width: 8; height: parent.height; opacity: 0.3 }
                        Dots { y: parent.height * (index + 1) / 3 - 4; width: parent.width; height: 8; opacity: 0.3 }
                    }
                }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: (index % 2 ? vf.width : 0) - 6
                        y: (index > 1 ? vf.height : 0) - 6
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.fg
                    }
                }

                // above the frame; at the top edge — inside
                Item {
                    y: vf.y > 70 ? -height - 18 : 18
                    width: parent.width
                    height: dims.height
                    Row {
                        x: 2
                        anchors.bottom: parent.bottom
                        spacing: 10
                        // recording — an accent dot: the only «live» thing on screen
                        Rectangle { visible: root.mode === 3; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: Theme.accent }
                        Lb { text: root.modes[root.mode]; color: Theme.fg }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        spacing: 14
                        Lb { anchors.bottom: parent.bottom; text: `${Math.round(root.sel.width * root.k)}×${Math.round(root.sel.height * root.k)} px` }
                        Num { id: dims; text: `${Math.round(root.sel.width * Theme.s)}×${Math.round(root.sel.height * Theme.s)}` }
                    }
                }
            }

            // the magnifier: the pixels under the cursor ×12, each — a dot (Dm with a pixel step), the coordinates and color below
            Item {
                id: loupe
                readonly property int px: Math.floor(root.mx * root.k)
                readonly property int py: Math.floor(root.my * root.k)
                readonly property int zoom: 12
                opacity: aim.t
                x: root.mx + 24 + width > stage.width ? root.mx - 24 - width : root.mx + 24
                y: root.my + 24 + height > stage.height ? root.my - 24 - height : root.my + 24
                width: 180
                height: 240

                // the pixel's color: read from a 1×1 canvas, it hides under the magnifier
                Canvas {
                    id: picker
                    property string hex: "#000000"
                    x: 90
                    y: 90
                    width: 1
                    height: 1
                    onImageLoaded: requestPaint()
                    onPaint: {
                        const g = getContext("2d"), src = frozenImg.source.toString();
                        if (!isImageLoaded(src)) return loadImage(src);
                        g.drawImage(src, loupe.px, loupe.py, 1, 1, 0, 0, 1, 1);
                        const d = g.getImageData(0, 0, 1, 1).data;
                        hex = "#" + [d[0], d[1], d[2]].map(v => v.toString(16).padStart(2, "0")).join("").toUpperCase();
                    }
                    Connections { target: loupe; function onPxChanged() { picker.requestPaint(); } function onPyChanged() { picker.requestPaint(); } }
                }

                Rectangle { x: 6; y: 6; width: 168; height: 168; radius: 84; color: Theme.bg }
                // 13 × 13 pixels; the dot grid matches the pixels: the center — the middle of the 7th cell
                Item {
                    x: 12
                    y: 12
                    width: 13 * loupe.zoom
                    height: 13 * loupe.zoom
                    layer.enabled: true
                    layer.effect: Dm { step: loupe.zoom; circle: true }
                    Image {
                        source: frozenImg.source
                        smooth: false
                        width: frozenImg.sourceSize.width * loupe.zoom
                        height: frozenImg.sourceSize.height * loupe.zoom
                        x: (6 - loupe.px) * loupe.zoom
                        y: (6 - loupe.py) * loupe.zoom
                    }
                }
                Rectangle { x: 80; y: 80; width: 20; height: 20; radius: 10; color: "transparent"; border { width: 1.5; color: Theme.fg } }
                Ring { width: 180; height: 180; n: 48; dot: 3 }

                Pill {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    height: 44
                    pad: 18
                    spacing: 12
                    Num { anchors.verticalCenter: parent.verticalCenter; text: `${Math.round(root.mx * Theme.s)} · ${Math.round(root.my * Theme.s)}`; font.pixelSize: 26 }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: picker.hex; border { width: 1; color: Theme.s3 } }
                    Lb { anchors.verticalCenter: parent.verticalCenter; text: picker.hex; px: 11 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                property point from
                onPositionChanged: e => {
                    root.mx = e.x;
                    root.my = e.y;
                    if (pressed && (root.mode === 0 || root.mode === 3))
                        root.drag = Qt.rect(Math.min(from.x, e.x), Math.min(from.y, e.y), Math.abs(e.x - from.x), Math.abs(e.y - from.y));
                }
                onPressed: e => {
                    if (root.mode === 1 || root.mode === 2) return root.fire(); // a window or the screen — shoot on click
                    from = Qt.point(e.x, e.y);
                    root.drag = Qt.rect(e.x, e.y, 0, 0);
                }
            }

            // modes and the timer — chips in a pill, the keys under it; they slide in from the bottom
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 44 - 24 * (1 - aim.t) }
                opacity: aim.t
                spacing: 12
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Repeater {
                        model: root.modes
                        Chip {
                            required property string modelData
                            required property int index
                            text: modelData
                            on: index === root.mode
                            onClicked: root.mode = index
                        }
                    }
                    Item { width: 18; height: 36; Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.mute } }
                    Chip {
                        text: root.delay ? `${root.delays[root.delay]}s` : "timer"
                        on: root.delay > 0
                        onClicked: root.delay = (root.delay + 1) % 3
                    }
                }
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 36
                    pad: 22
                    spacing: 28
                    Repeater {
                        model: ["drag select", "space window", "tab mode", "t timer", "↵ capture", "esc cancel"]
                        Lb { required property string modelData; text: modelData; px: 10 }
                    }
                }
            }
        }
    }

    // ============ the shot: the frame flashes, the shot slides in as a card to the bottom right corner ============
    PanelWindow {
        id: fired
        screen: root.scr
        visible: false
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: root.shotRec ? null : card } // clicks outside the card pass through
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "glyph-shot"

        Stage {
            id: fstage

            // the flash: the shot region glows white and fades. Recording — a red frame outside, no fill or glow:
            // the recorder starts while it fades, it mustn't get into the frame. ponytail: when recording the whole screen the frame is past the edge — not visible
            Rectangle {
                id: flash
                readonly property real o: root.shotRec ? 4 : 0
                x: root.shotRect.x - o
                y: root.shotRect.y - o
                width: root.shotRect.width + o * 2
                height: root.shotRect.height + o * 2
                color: root.shotRec ? "transparent" : Theme.fade(Theme.fg, 0.12)
                border { width: 2; color: root.shotRec ? Theme.accent : Theme.fg }
                layer.enabled: fired.visible && !root.shotRec
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.glow
                    shadowBlur: 0.7
                    blurMax: 20
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }

            // the card: Surface, rounding 40, the shot with rounding 24 — concentric
            Rectangle {
                id: card
                property real t: 0
                visible: !root.shotRec
                x: fstage.width - 28 - width + 48 * (1 - t)
                y: fstage.height - 28 - height
                opacity: t
                width: 360
                height: col.height + 32
                radius: Theme.corner(40)
                color: Theme.s1
                border { width: 1; color: Theme.s2 }

                Column {
                    id: col
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 16
                    Item {
                        width: parent.width
                        height: 184
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: thumbMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
                        Rectangle { anchors.fill: parent; color: Theme.s2 }
                        Image {
                            anchors.fill: parent
                            source: root.shot ? "file://" + root.shot : ""
                            sourceSize: Qt.size(328, 184)
                            fillMode: Image.PreserveAspectCrop
                            cache: false // after editing it's the same path — reload it
                        }
                    }
                    Item {
                        width: parent.width
                        height: cdims.height
                        Num { id: cdims; x: 8; text: root.shotDims; font.pixelSize: 30 }
                        Lb { anchors { right: parent.right; rightMargin: 8; bottom: parent.bottom } text: root.shotWhat; px: 11 }
                    }
                    Lb { x: 8; text: "copied · click to edit"; px: 10; color: Theme.mute }
                }
                Rectangle { id: thumbMask; width: 328; height: 184; radius: Theme.corner(24); visible: false; layer.enabled: true }

                TapHandler { onTapped: { fx.stop(); fired.visible = false; editor.open(root.shot, root.scr); } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        // the flash fades over 0.9 s, the card slides in from the right, hangs for a couple of seconds and leaves the same way
        SequentialAnimation {
            id: fx
            PropertyAction { target: fired; property: "visible"; value: true }
            ParallelAnimation {
                NumberAnimation { target: flash; property: "opacity"; from: 1; to: 0; duration: 900; easing.type: Easing.OutQuad }
                NumberAnimation { target: card; property: "t"; from: 0; to: 1; duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
            }
            PauseAnimation { duration: 2200 }
            NumberAnimation { target: card; property: "t"; to: 0; duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
            PropertyAction { target: fired; property: "visible"; value: false }
        }
    }

    // a dotted line: a row or column of dots at a step of 8 — a line 8 thick gives exactly one row
    component Dots: Image {
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><circle cx="4" cy="4" r="1.2" fill="#${Theme.hex(Theme.fg)}"/></svg>`)
    }
}
