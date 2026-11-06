pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.services
import qs.settings

// то, что трогают бар, быстрые настройки, Glyph и лок: звук, яркость, раскладка, запись, ночник, авиарежим, кофеин, vpn
Singleton {
    id: root

    // deck (панель снизу) открыта — SysStats нужен подробный опрос, как на пустом воркспейсе (Home)
    property bool deckOpen: false
    // пикер обоев открыт — дом меняет обои сразу, без волны: её уже показал пикер
    property bool wallOpen: false

    // ---- звук ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.mic] }
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool micOn: !(mic?.audio?.muted ?? true)
    function setVol(v) {
        if (!sink?.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    // микрофон кто-то слушает — центр знака в баре краснеет
    PwNodeLinkTracker { id: micUse; node: root.mic }
    readonly property bool live: rec || micUse.linkGroups.length > 0

    // ---- яркость: общий с demonshot Backlight (устройство ищет brightnessctl) ----
    readonly property real bri: Backlight.value
    readonly property bool hasBri: !!Backlight.dev // нет подсветки (ПК с монитором) — регуляторов яркости нет
    function setBri(v) { Backlight.set(v); }
    // яркость того монитора, где открыли панель: встроенный — подсветка, внешний — DDC. Панель живёт на
    // одном экране, но Super+A и peek с горячего края открывают её «на» фокусе Hyprland
    property string panelMon: ""
    readonly property bool panelBriExternal: panelMon !== "" && !panelMon.startsWith("eDP")
    readonly property real panelBri: panelBriExternal ? Backlight.ddc : Backlight.value
    function setPanelBri(v) { panelBriExternal ? Backlight.setDdc(v) : Backlight.set(v); }
    readonly property bool ddcOk: Backlight.ddcOk // есть ли внешний с DDC (панель прячет слайдер, пока он не ответит)
    Binding { target: Backlight; property: "steps"; value: Theme.state.briSteps }

    // ---- раскладка: старт — main-клавиатура из hyprctl, дальше событие activelayout ----
    property string kbd: ""
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: root.kbd = JSON.parse(this.text).keyboards.find(k => k.main)?.active_keymap ?? "" }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") root.kbd = e.data.slice(e.data.lastIndexOf(",") + 1); }
    }
    readonly property string layout: kbd.slice(0, 2).toLowerCase() // "English (US)" → en

    // ---- запись и авиарежим: их же включают бинды hypr, поэтому опрос. Ночник — общий с demonshot, в его rules.json
    // ponytail: pgrep раз в 3 с; станет заметно — следить за процессами через systemd-run --scope ----
    property bool rec: false
    readonly property bool night: Rules.store.night
    property bool air: false
    Process {
        id: poll
        command: ["sh", "-c", "pgrep -f '^gpu-screen-recorder' >/dev/null && echo rec; "
                            + "rfkill -rno SOFT | grep -qv '^blocked' || echo air"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.rec = text.includes("rec");
                root.air = text.includes("air");
            }
        }
    }
    Timer { running: true; repeat: true; interval: 3000; triggeredOnStart: true; onTriggered: poll.running = true }

    function sh(c) { Quickshell.execDetached(["sh", "-c", c]); }
    // настройки записи из Theme.state (quick/Rec) → флаги gpu-screen-recorder; их же берёт скриншотилка
    readonly property var recFps: [30, 60, 120]
    function recArgs() {
        const st = Theme.state;
        const a = ["", "default_output", "default_input", "default_output|default_input"][st.recAudio];
        return `-f ${st.recFps} -q ${["medium", "high", "very_high", "ultra"][st.recQuality]} -cursor ${st.recCursor ? "yes" : "no"}` + (a ? ` -a "${a}"` : "");
    }
    // второй раз — стоп. Область — slurp; отменили выбор — gsr не стартует, rec поправит опрос
    function toggleRec() {
        const w = Theme.state.recArea ? `-w region -region "$(slurp -f %wx%h+%x+%y)"` : `-w ${Hyprland.focusedMonitor?.name ?? "screen"}`;
        sh(`pkill -INT -f '^gpu-screen-recorder' || exec gpu-screen-recorder ${w} ${recArgs()} -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"`);
        rec = !rec;
    }
    function toggleNight() { Rules.store.night = !night; Rules.night(); }
    function toggleAir() { Quickshell.execDetached(["rfkill", air ? "unblock" : "block", "all"]); air = !air; }
    function toggleMic() { if (mic?.audio) mic.audio.muted = !mic.audio.muted; }

    // ---- наушники Nothing / CMF: шумодав и заряд через ./ear (их RFCOMM-протокол). Спрашиваем при открытии быстрых настроек.
    // ponytail: узнаём по имени, как Gadgetbridge; не Nothing — ear не ответит, ear останется null ----
    readonly property var buds: Bluetooth.devices.values.find(d => d.connected && /^(nothing|cmf|ear)\b/i.test(d.name)) ?? null
    property var ear: null // {mode, l, r, case?}
    onBudsChanged: ear = null
    // сразу после подключения канал ещё не готов — спрашивать раз в 2 с, пока не ответят. ponytail: не Nothing с похожим
    // именем так и будет опрашиваться, пока подключено
    Timer { interval: 2000; repeat: true; running: !!root.buds && !root.ear; onTriggered: root.earRun([]) }
    readonly property var ancModes: [[5, "off"], [7, "transp"], [3, "low"], [2, "mid"], [1, "high"], [4, "auto"]]
    property var earNext: null
    function earRun(a) {
        if (!buds) return;
        const c = [Quickshell.shellPath("ear"), buds.address, ...a];
        if (earP.running) earNext = c;
        else { earP.command = c; earP.running = true; }
    }
    function setAnc(m) { ear = Object.assign({}, ear, { mode: m }); earRun(["mode", m]); }
    Process {
        id: earP
        stdout: StdioCollector { onStreamFinished: { try { root.ear = JSON.parse(text); } catch (e) { root.ear = null; } } }
        onExited: if (root.earNext) { command = root.earNext; root.earNext = null; running = true; }
    }

    // ---- кофеин: не спать. Ингибитору нужно живое окно — невидимое 0×0, как в demonshot ----
    property bool caffeine: false
    IdleInhibitor {
        enabled: root.caffeine
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "glyph-caffeine"
            mask: Region {}
        }
    }

    // ---- vpn: clash verge через пункты его трея, как договор в demonshot.
    // ponytail: подписи английские (language: en в verge); другой язык — поменять строки ----
    readonly property var verge: SystemTray.items.values.find(i => i.title === "clash-verge" || i.id.includes("clash-verge")) ?? null
    QsMenuOpener { id: vmenu; menu: root.verge?.menu ?? null }
    readonly property var vpnItems: ["System Proxy", "TUN Mode"]
    function vpnItem(l) { return vmenu.children.values.find(e => e.text.startsWith(l)) ?? null; }
    readonly property bool vpn: vpnItems.some(l => vpnItem(l)?.checkState === Qt.Checked)
    property var queue: []
    function toggleVpn() {
        if (!verge) return Quickshell.execDetached(["clash-verge"]); // спит — разбудить
        queue = vpn ? vpnItems.filter(l => vpnItem(l)?.checkState === Qt.Checked) : vpnItems;
        presser.start();
    }
    // verge пересобирает меню после каждого нажатия — по одному
    Timer {
        id: presser
        interval: 350
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const [l, ...rest] = root.queue;
            root.queue = rest;
            if (l) root.vpnItem(l)?.triggered();
            if (!rest.length) stop();
        }
    }
}
