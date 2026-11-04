import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// the hot edge: the cursor lingered at the edge opposite the bar (usually the right) — quick settings slide out (Quick.peek).
// A 2px strip along the bottom 80%: barely touches the top corner and scrollbars at the edge
PanelWindow {
    id: root

    signal triggered

    visible: Theme.state.quickHover
    anchors { right: !Theme.state.barRight; left: Theme.state.barRight; bottom: true }
    implicitWidth: 2
    implicitHeight: Math.round(screen.height * 0.8)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glyph-hot"

    HoverHandler { id: hov; onHoveredChanged: hovered ? dwell.restart() : dwell.stop() }
    Timer { id: dwell; interval: 150; onTriggered: if (hov.hovered) root.triggered() }
}
