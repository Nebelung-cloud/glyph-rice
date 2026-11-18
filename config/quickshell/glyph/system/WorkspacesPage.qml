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
Sheet {
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

    readonly property Component overview: Component {
        Row {
            spacing: 10
            Repeater {
                model: Theme.state.wsCount
                Rectangle {
                    required property int index
                    width: 54
                    height: 54
                    radius: Theme.corner(14)
                    color: index === 0 ? Theme.fg : Theme.s1
                    border { width: 1; color: Theme.s2 }
                    Num { anchors.centerIn: parent; text: parent.index + 1; font.pixelSize: 22; color: parent.index === 0 ? Theme.ink : Theme.grey }
                }
            }
        }
    }

    Lb { topPadding: 8; bottomPadding: 4; text: "workspaces" }
    Opt {
        title: "Workspaces"
        hint: "How many in each group of ten."
        about: "Super + a number goes to that workspace. This sets how many exist per group, and how many the overview offers. The overview's − and + change the same number."
        value: `${cnt.v}`
        preview: root.overview
        Dial { id: cnt; size: 72; n: 10; from: 1; to: 10; value: Theme.state.wsCount; onMoved: v => Theme.state.wsCount = v }
    }
    Opt {
        title: "Wrap around"
        hint: "Going past the last workspace comes back to the first."
        about: "With this on, moving to the next workspace from the last one lands on the first, and the other way round."
        value: Theme.state.wsWrap ? "on" : "off"
        Switch { on: Theme.state.wsWrap; onFlip: Theme.state.wsWrap = !Theme.state.wsWrap }
    }
    Opt {
        title: "Bar shows"
        hint: "Which workspaces get a dot in the bar."
        about: "In use shows six dots, plus any further workspace that has windows or that you're on. All shows every workspace up to the count above."
        value: ["in use", "all"][Theme.state.wsBar] ?? ""
        Pick { opts: ["in use", "all"]; cur: Theme.state.wsBar; onPicked: i => Theme.state.wsBar = i }
    }
    Opt {
        title: "Switching animation"
        hint: "How the screen moves to another workspace."
        about: "Vertical slides up and down, sideways slides left and right, fade crossfades without moving."
        value: ["vertical", "sideways", "fade"][["slidevert", "slide", "fade"].indexOf(Theme.state.wsAnim)] ?? ""
        Pick { opts: ["vertical", "sideways", "fade"]; cur: ["slidevert", "slide", "fade"].indexOf(Theme.state.wsAnim); onPicked: i => Theme.state.wsAnim = ["slidevert", "slide", "fade"][i] }
    }
    Opt {
        title: "Blur special workspaces"
        hint: "Blur what's behind a special workspace."
        about: "Special workspaces open over the current one, like a drop-down. With this on, the windows behind them are blurred."
        value: Theme.state.wsBlurSpecial ? "on" : "off"
        Switch { on: Theme.state.wsBlurSpecial; onFlip: Theme.state.wsBlurSpecial = !Theme.state.wsBlurSpecial }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: root.specials.length ? "special workspaces · from your hypr config" : "no special workspaces in your hypr config" }
    Repeater {
        model: root.specials
        Opt {
            required property var modelData
            readonly property int open_: Hyprland.workspaces.values.find(w => w.name === `special:${modelData.name}`)?.toplevels.values.length ?? 0
            title: modelData.name
            hint: [modelData.key, modelData.app ? modelData.app.split(" ")[0] : "", open_ ? `${open_} open` : "empty"].filter(Boolean).join(" · ")
            about: "A workspace that drops over the current one and hides again with the same key. Open shows it; if it's empty, its app starts too. This panel closes."
            value: open_ ? `${open_} open` : "empty"
            Act { icon: root.icon(modelData.name); text: "open"; onHit: root.open(modelData) }
        }
    }
}
