import QtQuick

// a dot mask for layer.effect: `layer.enabled: true; layer.effect: Dm { step: 6 }` — covers, weather, the orb on the wallpaper
ShaderEffect {
    property real step: 5
    readonly property real pitch: step // the shader uniform: the name step is taken in GLSL
    property bool circle: false // dots only inside a circle
    readonly property real circ: circle ? 1 : 0
    readonly property size size: Qt.size(width, height)
    fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
}
