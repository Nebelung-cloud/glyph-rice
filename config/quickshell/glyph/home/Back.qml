import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// подложка дома, отдельным окном на слое background: сетка точек, полутоновый шар, обои. Сам дом (часы, бенто) — слоем
// выше, прозрачный: он перерисовывается часто (двоеточие, кольца, крутящаяся обложка), а обои — полноэкранный шейдер,
// и в одном окне считались бы на каждый его кадр. Здесь кадр — только на волну, смену вида и дыхание шара.
// Картинка закрыла всё — сетку и шар не рисуем, шар не дышит: окно стоит
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "glyph-back"

    readonly property bool home: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) === 0
    property real phase: 0
    Timer { running: root.home && orb.visible; interval: 100; repeat: true; onTriggered: root.phase += 0.1 }

    Stage {
        id: stage
        Image {
            visible: Theme.state.grid && !wall.opaque
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }
        Orb { id: orb; visible: Theme.state.orb && !wall.opaque; x: stage.width - 720; y: stage.height - 580; phase: root.phase }
        Wall { id: wall; anchors.fill: parent; path: Theme.wallSrc(Theme.scr(root.screen?.name, "wall")); animate: !Sys.wallOpen }
    }
}
