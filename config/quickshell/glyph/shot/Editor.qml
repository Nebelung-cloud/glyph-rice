import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// editing a shot: the screen almost black, the shot in a frame with dots at the corners, like a viewfinder; tools — chips in a pill,
// inks — circles, thickness — dots. Marks live in the shot's pixels; ⏎ bakes them over the file (grabToImage at native size) and puts it on the clipboard
Scope {
    id: root

    readonly property var tools: ["pen", "arrow", "rect", "blur", "text"]
    readonly property var hotkeys: [Qt.Key_P, Qt.Key_A, Qt.Key_R, Qt.Key_B, Qt.Key_T]
    // inks are baked into the file — they don't depend on the theme. Red here is the shot's content, not the interface
    readonly property var inks: [Theme.nothingRed, "#FFFFFF", "#000000", "#8C8C8C"]
    readonly property var sizes: [3, 6, 12] // thickness in logical pixels; in the shot — × dpr

    property string shot: ""
    property var scr: null
    property int tool: 0
    property int ink: 0
    property int size: 1
    property var marks: []  // { k: "pen", c, w, pts } · { k: "arrow" | "rect" | "blur", c, w, x1, y1, x2, y2 } · { k: "text", c, s, x, y, t }
    property var live: null // the mark being dragged right now
    readonly property real dpr: scr?.devicePixelRatio ?? 1
    readonly property real w: sizes[size] * dpr

    function open(path, screen) {
        shot = path;
        scr = screen;
        marks = [];
        live = null;
        typing.visible = false;
        win.shown = true;
        st.forceActiveFocus();
    }
    function close() { win.shown = false; }

    function commitWord() {
        if (!typing.visible) return;
        if (typing.text.trim())
            marks = marks.concat([{ k: "text", c: inks[ink], s: typing.font.pixelSize, x: typing.x, y: typing.y, t: typing.text }]);
        typing.visible = false;
        st.forceActiveFocus();
    }

    function save() {
        commitWord();
        // ponytail: the shot is overwritten; keep the original alongside — if you ever want to roll edits back
        canvas.grabToImage(r => {
            if (!r.saveToFile(root.shot)) return;
            Quickshell.execDetached(["sh", "-c", 'wl-copy -t image/png < "$1"', "sh", root.shot]);
            root.close();
        }, Qt.size(img.implicitWidth, img.implicitHeight));
    }

    PanelWindow {
        id: win

        property bool shown: false
        property real t: shown ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

        screen: root.scr
        visible: t > 0
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "glyph-shot"

        Rectangle { anchors.fill: parent; color: Theme.fade(Theme.bg, 0.96); opacity: win.t }

        Stage {
            id: st
            focus: true
            Keys.onPressed: e => {
                const t = root.hotkeys.indexOf(e.key);
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (e.key === Qt.Key_S && e.modifiers & Qt.ControlModifier)) root.save();
                else if (e.key === Qt.Key_Z && e.modifiers & Qt.ControlModifier) root.marks = root.marks.slice(0, -1);
                else if (t >= 0) root.tool = t;
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) root.ink = e.key - Qt.Key_1;
                else if (e.key === Qt.Key_BracketLeft) root.size = Math.max(0, root.size - 1);
                else if (e.key === Qt.Key_BracketRight) root.size = Math.min(2, root.size + 1);
                else return;
                e.accepted = true;
            }

            // the shot fits between the labels and the pill, doesn't grow past 1:1; slides in from 96%
            Item {
                id: frame
                readonly property real fit: Math.min(1 / (root.dpr * Theme.s), (st.width - 240) / Math.max(1, img.implicitWidth),
                                                     (st.height - 140 - 220) / Math.max(1, img.implicitHeight))
                width: img.implicitWidth * fit
                height: img.implicitHeight * fit
                x: (st.width - width) / 2
                y: 140 + (st.height - 140 - 220 - height) / 2
                opacity: win.t
                scale: 0.96 + 0.04 * win.t

                Item {
                    id: canvas
                    width: img.implicitWidth
                    height: img.implicitHeight
                    scale: frame.fit
                    transformOrigin: Item.TopLeft

                    Image {
                        id: img
                        source: root.shot ? "file://" + root.shot : ""
                        cache: false // after saving it's the same path — reload it
                        smooth: true
                        mipmap: true
                    }
                    Repeater {
                        // the live mark — last; its delegate is recreated on every mouse step, the rest — only when committed
                        model: root.marks
                        Mark { required property var modelData; m: modelData; src: img }
                    }
                    Repeater {
                        model: root.live ? [root.live] : []
                        Mark { required property var modelData; m: modelData; src: img }
                    }

                    TextInput {
                        id: typing
                        visible: false
                        font { family: Theme.ui; pixelSize: root.w * 6; weight: Font.DemiBold }
                        color: root.inks[root.ink]
                        selectionColor: Theme.s3
                        cursorDelegate: Rectangle { width: 2 * root.dpr; color: Theme.accent } // the caret — «live»
                        onAccepted: root.commitWord()
                        Keys.onEscapePressed: { visible = false; st.forceActiveFocus(); }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.tool === 4 ? Qt.IBeamCursor : Qt.CrossCursor
                        onPressed: e => {
                            root.commitWord();
                            const c = root.inks[root.ink];
                            if (root.tool === 0) root.live = { k: "pen", c, w: root.w, pts: [Qt.point(e.x, e.y)] };
                            else if (root.tool === 4) {
                                typing.text = "";
                                typing.x = e.x;
                                typing.y = e.y - typing.height / 2;
                                typing.visible = true;
                                typing.forceActiveFocus();
                            } else root.live = { k: root.tools[root.tool], c, w: root.w, x1: e.x, y1: e.y, x2: e.x, y2: e.y };
                        }
                        onPositionChanged: e => {
                            const l = root.live;
                            if (!l) return;
                            // ponytail: the stroke is copied on every step — O(n²), enough for strokes of thousands of points
                            if (l.k === "pen") root.live = Object.assign({}, l, { pts: l.pts.concat([Qt.point(e.x, e.y)]) });
                            else root.live = Object.assign({}, l, { x2: e.x, y2: e.y });
                        }
                        onReleased: {
                            const l = root.live;
                            root.live = null;
                            if (l && (l.k === "pen" ? l.pts.length > 1 : Math.hypot(l.x2 - l.x1, l.y2 - l.y1) > 4 * root.dpr))
                                root.marks = root.marks.concat([l]);
                        }
                    }
                }

                // the frame and the dots at the corners — like a viewfinder
                Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border { width: 1; color: Theme.s3 } }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: (index % 2 ? frame.width : 0) - 6
                        y: (index > 1 ? frame.height : 0) - 6
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.fg
                    }
                }
                Item {
                    y: -height - 18
                    width: parent.width
                    height: dims.height
                    Lb { x: 2; anchors.bottom: parent.bottom; text: `edit · ${root.tools[root.tool]}`; color: Theme.fg }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        spacing: 14
                        Lb { anchors.bottom: parent.bottom; text: `${root.marks.length} ${root.marks.length === 1 ? "mark" : "marks"}` }
                        Num { id: dims; text: `${img.implicitWidth}×${img.implicitHeight}` }
                    }
                }
            }

            // tools — chips; then inks as circles and thickness as dots. They slide in from the bottom
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 44 - 24 * (1 - win.t) }
                opacity: win.t
                spacing: 12
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Repeater {
                        model: root.tools
                        Chip {
                            required property string modelData
                            required property int index
                            text: modelData
                            on: index === root.tool
                            onClicked: { root.commitWord(); root.tool = index; }
                        }
                    }
                    Sep {}
                    Repeater {
                        model: root.inks
                        // the selected ink — in a White ring
                        Item {
                            required property color modelData
                            required property int index
                            width: 30
                            height: 36
                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: "transparent"
                                border { width: 1.5; color: index === root.ink ? Theme.fg : "transparent" }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 8
                                color: modelData
                                border { width: 1; color: Theme.s3 }
                            }
                            TapHandler { onTapped: root.ink = index }
                        }
                    }
                    Sep {}
                    Repeater {
                        model: root.sizes
                        Item {
                            required property int modelData
                            required property int index
                            width: 26
                            height: 36
                            Rectangle {
                                anchors.centerIn: parent
                                width: modelData + 4
                                height: width
                                radius: width / 2
                                color: index === root.size ? Theme.fg : Theme.mute
                                Behavior on color { ColorAnimation { duration: Theme.t } }
                            }
                            TapHandler { onTapped: root.size = index }
                        }
                    }
                    Item { width: 8; height: 36 }
                }
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 36
                    pad: 22
                    spacing: 28
                    Repeater {
                        model: ["p a r b t tool", "1–4 ink", "[ ] size", "ctrl+z undo", "↵ save · copy", "esc discard"]
                        Lb { required property string modelData; text: modelData; px: 10 }
                    }
                }
            }
        }
    }

    // a separator in the pill — a Mute dot
    component Sep: Item {
        width: 18
        height: 36
        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.mute }
    }

    // one mark in the shot's pixels
    component Mark: Item {
        id: mk
        property var m
        property Item src // the shot for blur: the file's ids aren't visible inside an inline component
        readonly property real x0: Math.min(m.x1, m.x2)
        readonly property real y0: Math.min(m.y1, m.y2)
        readonly property real w0: Math.abs(m.x2 - m.x1)
        readonly property real h0: Math.abs(m.y2 - m.y1)

        Loader {
            sourceComponent: ({ pen: pen, arrow: arrow, rect: rectC, blur: blur, text: word })[mk.m.k]
        }

        Component {
            id: pen
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mk.m.c
                    strokeWidth: mk.m.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: mk.m.pts }
                }
            }
        }
        Component {
            id: arrow
            Shape {
                id: ar
                // the arrowhead — a triangle 4 thicknesses long, the shaft up to its base
                readonly property real a: Math.atan2(mk.m.y2 - mk.m.y1, mk.m.x2 - mk.m.x1)
                readonly property real hl: mk.m.w * 4
                readonly property point base: Qt.point(mk.m.x2 - Math.cos(a) * hl * 0.8, mk.m.y2 - Math.sin(a) * hl * 0.8)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mk.m.c
                    strokeWidth: mk.m.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: [Qt.point(mk.m.x1, mk.m.y1), ar.base] }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: mk.m.c
                    PathPolyline {
                        path: [Qt.point(mk.m.x2, mk.m.y2),
                               Qt.point(mk.m.x2 - Math.cos(ar.a - 0.45) * ar.hl, mk.m.y2 - Math.sin(ar.a - 0.45) * ar.hl),
                               Qt.point(mk.m.x2 - Math.cos(ar.a + 0.45) * ar.hl, mk.m.y2 - Math.sin(ar.a + 0.45) * ar.hl),
                               Qt.point(mk.m.x2, mk.m.y2)]
                    }
                }
            }
        }
        Component {
            id: rectC
            Rectangle {
                x: mk.x0 - mk.m.w / 2
                y: mk.y0 - mk.m.w / 2
                width: mk.w0 + mk.m.w
                height: mk.h0 + mk.m.w
                color: "transparent"
                border { width: mk.m.w; color: mk.m.c }
            }
        }
        // blur: a piece of the shot in large pixels — passwords, faces, addresses
        Component {
            id: blur
            ShaderEffectSource {
                readonly property real px: mk.m.w * 3
                x: mk.x0
                y: mk.y0
                width: mk.w0
                height: mk.h0
                sourceItem: mk.src
                sourceRect: Qt.rect(mk.x0, mk.y0, mk.w0, mk.h0)
                textureSize: Qt.size(Math.max(1, Math.ceil(mk.w0 / px)), Math.max(1, Math.ceil(mk.h0 / px)))
                smooth: false
            }
        }
        Component {
            id: word
            Text {
                x: mk.m.x
                y: mk.m.y
                text: mk.m.t
                font { family: Theme.ui; pixelSize: mk.m.s; weight: Font.DemiBold }
                color: mk.m.c
                style: Text.Outline
                styleColor: Qt.colorEqual(mk.m.c, "#000000") ? "#FFFFFF" : "#000000"
            }
        }
    }
}
