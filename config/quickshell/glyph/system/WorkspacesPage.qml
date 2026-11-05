import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.components
import "../prefs"

// workspaces: how many per group of ten (the same −/+ as in the overview), whether ±1 wraps, what the bar shows, how to switch, blur on
// special workspaces. Below — the special workspaces from your own hypr config: the fn.toggle_special("…") binds in keybinds.lua, keys and programs
// from variables.lua. A click — open the workspace (an empty one — launch its program, like the bind), the System window closes
Page {
    id: root
    property bool live
    signal done // a special workspace was shown — System gets out of the way
    caption: `workspaces · ${Theme.state.wsCount} per group`

    property var specials: []
    Process {
        running: root.live
        command: ["sh", "-c", `k=$HOME/.config/hypr/hyprland/keybinds.lua; v=$HOME/.config/hypr/variables.lua
grep -oE 'hl\\.bind\\(vars\\.[A-Za-z]+, *fn\\.toggle_special\\("[A-Za-z0-9_-]+"\\)' "$k" | sed -E 's/hl\\.bind\\(vars\\.([A-Za-z]+), *fn\\.toggle_special\\("([^"]+)"\\)/\\1 \\2/' | while read -r var name; do
  key=$(grep -E "^\\s*$var\\s*=" "$v" | head -n1 | sed -E 's/[^"]*"([^"]*)".*/\\1/')
  app=$(grep -E "^\\s*$name\\s*=\\s*\\"" "$v" | head -n1 | sed -E 's/[^"]*"([^"]*)".*/\\1/')
  printf '%s\\t%s\\t%s\\n' "$name" "$key" "$app"; done`]
        stdout: StdioCollector { onStreamFinished: root.specials = text.split("\n").filter(Boolean).map(l => { const [name, key, app] = l.split("\t"); return { name, key, app }; }) }
    }
    function open(s) {
        const busy = Hyprland.workspaces.values.some(w => w.name === `special:${s.name}` && w.toplevels.values.length);
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${s.name}")`);
        // like the bind: show first, then launch, otherwise the window would open elsewhere
        if (!busy && s.app) Quickshell.execDetached(["sh", "-c", s.app]);
        done();
    }
    function icon(n) { return { music: "\u{F075A}", communication: "\u{F0369}", sysmon: "\u{F0128}", todo: "\u{F0C52}" }[n] ?? "\u{F0570}"; }

    Row {
        spacing: 60
        Dial { size: 220; n: 10; from: 1; to: 10; label: "workspaces"; value: Theme.state.wsCount; onMoved: v => Theme.state.wsCount = v }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Toggle { text: "wrap around · last → first"; on: Theme.state.wsWrap; onFlip: Theme.state.wsWrap = !Theme.state.wsWrap }
            Pick { label: "bar shows"; opts: ["in use", "all"]; cur: Theme.state.wsBar; onPicked: i => Theme.state.wsBar = i }
            Pick { label: "switch"; opts: ["vertical", "sideways", "fade"]; cur: ["slidevert", "slide", "fade"].indexOf(Theme.state.wsAnim); onPicked: i => Theme.state.wsAnim = ["slidevert", "slide", "fade"][i] }
            Toggle { text: "blur special workspaces"; on: Theme.state.wsBlurSpecial; onFlip: Theme.state.wsBlurSpecial = !Theme.state.wsBlurSpecial }
        }
    }

    Column {
        width: 950
        spacing: 4
        Lb { x: 8; bottomPadding: 6; text: root.specials.length ? `special workspaces · ${root.specials.length} · from your hypr config` : "no special workspaces in your hypr config" }
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: root.specials
                Line {
                    required property var modelData
                    readonly property int open_: Hyprland.workspaces.values.find(w => w.name === `special:${modelData.name}`)?.toplevels.values.length ?? 0
                    width: 466
                    icon: root.icon(modelData.name)
                    title: modelData.name
                    sub: [modelData.key, modelData.app ? modelData.app.split(" ")[0] : "", open_ ? `${open_} open` : "empty"].filter(Boolean).join(" · ")
                    on: open_ > 0
                    onHit: root.open(modelData)
                }
            }
        }
    }
    Lb { text: "super + tab · overview · drag windows between workspaces" }
}
