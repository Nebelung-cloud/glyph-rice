pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

// house rules: ~/.config/demonshot/rules.json — единственный источник правды для настроек.
// Правка из Settings пишет файл (writeAdapter) и сама зовёт нужный apply. applyAll зовёт только shell.qml на старте:
// лок (lock.qml) тоже читает Theme → Rules, но ничего не применяет
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/demonshot"
    readonly property alias store: adapter

    // восемь цветов в порядке Theme: void crypt wine plum rose crimson ash bone
    readonly property var palettes: [
        { name: "Demon's Shot", what: "blood & bone", c: ["#0D0B0E", "#151116", "#2B1820", "#4A2236", "#B8487A", "#C7303D", "#7A6870", "#E9DFDD"] },
        { name: "Absinthe", what: "green fairy", c: ["#0B0D0B", "#121612", "#1E2A1F", "#2F4630", "#A9B85A", "#7CC24A", "#6E7A6C", "#E3E6D8"] },
        { name: "Nightshade", what: "poison bloom", c: ["#0C0B10", "#131119", "#221A30", "#3A2852", "#8E6BD8", "#B04BD6", "#706A80", "#E4DFEA"] },
        { name: "Holy Water", what: "cold blessing", c: ["#0A0C10", "#11151B", "#1A2433", "#263C57", "#5E9BD1", "#3F7FE0", "#687687", "#DDE4EA"] },
        { name: "Rust", what: "old iron", c: ["#0E0B09", "#17120F", "#2E1D14", "#4D2E1C", "#D08A3E", "#D1532A", "#7E6E62", "#EADFD3"] },
        { name: "Gilded", what: "altar gold", c: ["#0D0C0A", "#16140F", "#2E2716", "#4A3D1E", "#B88A4A", "#D9A43A", "#7A7262", "#EDE5D3"] },
        { name: "Ghost", what: "no color left", c: ["#0C0C0D", "#141416", "#26262A", "#3A3A40", "#9A9AA6", "#E9E9EE", "#6E6E76", "#E2E2E6"] }
    ]
    readonly property var pal: palettes[adapter.palette] ?? palettes[0]

    // ждём файл при создании синглтона: иначе первый, кто прочтёт store (glyph на старте), получит умолчания, а не rules.json
    Component.onCompleted: file.waitForJob()

    FileView {
        id: file
        path: root.dir + "/rules.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: this.reload()
        // запись — раз в конце хода: writeAdapter() на каждое поле подряд путает соседние (пресет меняет четыре разом)
        onAdapterUpdated: Qt.callLater(file.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) this.writeAdapter(); } // первый запуск: файл с умолчаниями

        // умолчания — как в hypr-конфиге сейчас, чтобы первый запуск ничего не сдвинул
        JsonAdapter {
            id: adapter
            // Display
            property real monScale: 0   // 0 — auto, решает hypr ( demonshot: главный монитор; бывают дробные 1.25/1.5 )
            property int refresh: 120   // demonshot: герцы главного монитора
            property var monPrefs: ({}) // glyph: настройки каждого экрана по имени: { <name>: { scale, hz, bri } }
            property int brightness: 62
            property bool night: false
            property int warmth: 4300
            property int gapsIn: 6
            property int gapsOut: 14
            property int border: 2
            property int rounding: 0
            property bool blur: true
            property bool shadow: true
            property bool motion: true
            property bool ultra: false   // режим ultra (setMode 0): 60 Гц и без украшений поверх настроек
            property bool game: false    // игровой, как в caelestia: без анимаций, blur, теней, зазоров и скруглений, tearing (Theme.apply)
            // Colors
            property int palette: 0
            property bool paintHypr: true
            property bool paintKitty: true
            // Input — как в hyprland/input.lua
            property int kbSwitch: 0      // индекс в switches
            property int repeatDelay: 250
            property int repeatRate: 35
            property bool natural: true
            property bool tap: true
            property bool typingOff: false
            property int scroll: 30       // % — scroll_factor 0.3
            property int sens: 0          // -100…100 → sensitivity -1…1
            property bool flat: false
            // Idle: минуты, 0 — никогда
            property int lockAfter: 3
            property int dpmsAfter: 5
            property int sleepAfter: 10
            property bool hibernate: true // suspend-then-hibernate
            // System
            property bool roman: true
            // Notices. Тишина (её же ставят обереги): обычные уведомления не показываются, критические — всегда
            property bool dnd: false
            property int noteTime: 6      // с, если приложение не задало своё; 0 — ждут, пока не смахнут
            property int noteDeck: 5      // сколько видно в колоде
        }
    }

    // kitty: include-файл с цветами палитры (kitty.conf подключает его), SIGUSR1 — перечитать конфиг
    FileView { id: kitty; path: root.dir + "/kitty.conf"; printErrors: false }

    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // ---- мониторы: не зашит ни один — из hyprctl monitors все, встроенный (eDP) — «главный» для старых настроек.
    // У каждого свои масштаб и герцы (prefs.monScale/monHz), режим — самый большой из его, частоты — те, что у родного ----
    property var mons: [] // { name, w, h, scale, hz, rates[] }
    property bool monWanted: false // monitor() позвали раньше, чем пришёл ответ hyprctl
    readonly property var mon: mons.find(m => m.name.startsWith("eDP")) ?? mons[0] ?? { name: "", w: 0, h: 0, scale: 1, hz: 60, rates: [] }
    Process {
        id: monProc
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = JSON.parse(text).map(m => {
                    const modes = m.availableModes.map(s => /(\d+)x(\d+)@([\d.]+)/.exec(s)).filter(Boolean).map(r => [+r[1], +r[2], +r[3]]);
                    const [w, h] = modes.reduce((a, b) => b[0] * b[1] > a[0] * a[1] ? b : a, [m.width, m.height]);
                    // родные герцы, как их зовут в EDID: 99.93 → 99, 74.97 → 74, 59.94…60.02 → 60 (одна семья).
                    // 50 и прочие < 60 — видеочастоты (CEA), для рабочего стола не показываем.
                    // hypr строку вида 1920x1080@99 ставит на ближайший родной режим — сам @100 годами ложился на 99.93
                    const raw = modes.filter(r => r[0] === w && r[1] === h).map(r => r[2]);
                    const rates = [...new Set(raw.map(p => Math.round(p)))]
                        .map(hz => Math.floor(Math.max(...raw.filter(p => Math.round(p) === hz))))
                        .filter(hz => hz >= 60)
                        .sort((a, b) => a - b);
                    return { name: m.name, w, h, scale: m.scale, hz: Math.round(m.refreshRate), rates: rates.length ? rates : [60] };
                });
                if (!names.length) return;
                root.mons = names;
                if (root.monWanted) root.monitor();
            }
        }
    }
    // auto — масштаб выбирает hypr; какой вышел, узнаём, перечитав мониторы. Меняли герцы/масштаб снаружи (reload,
    // горячая клавиша) — сравниваем «до/после» и накатываем свои, иначе цикл применений не сойдётся
    property var monStamp: []
    property bool monCheck: false
    Timer { id: monReread; interval: 500; onTriggered: {
        monStamp = root.mons.map(m => `${m.name}:${m.scale}:${m.hz}`);
        root.monCheck = true;
        monProc.running = true;
    } }
    onMonsChanged: {
        if (!monCheck) return; // перечитывали после своего применения — сравниваем, прочие смены (hotplug) не трогаем
        monCheck = false;
        const now = root.mons.map(m => `${m.name}:${m.scale}:${m.hz}`);
        const same = monStamp.length === now.length && monStamp.every((s, i) => s === now[i]);
        monStamp = now;
        if (!same) root.monitor();
    }
    // настройки экрана того монитора, где открыты настройки (Rules.prefsMon): масштаб, герцы и их яркость.
    // Яркость — своя у каждого: встроенный — подсветка, внешний — DDC. Нет записи — умолчания
    function monP(name) {
        const m = mons.find(m => m.name === name) ?? mon;
        return {
            mon: m,
            scale: store.monPrefs[name]?.scale ?? 0,
            scaleIdx: store.monPrefs[name]?.scale ? scales.indexOf(String(store.monPrefs[name].scale)) : 0,
            hz: store.monPrefs[name]?.hz || m.hz,
            bri: (store.monPrefs[name]?.bri ?? -1) >= 0 ? store.monPrefs[name].bri : store.brightness,
            rates: m.rates.length ? m.rates : [60]
        };
    }
    // ближайшая родная частота к выбранной, а поставили снаружи — та, что вышла
    function nearHz(name) {
        const p = monP(name);
        return p.rates.reduce((a, b) => Math.abs(b - p.hz) < Math.abs(a - p.hz) ? b : a);
    }
    // применить один монитор; без имени — все
    function monitor(which) {
        const list = which ? mons.filter(m => m.name === which) : mons;
        if (!list.length) { monWanted = true; return; }
        monWanted = false;
        for (const m of list) {
            const rate = store.ultra ? m.rates[0] : nearHz(m.name); // ultra роняет герцы на всех экранах
            hypr(`hl.monitor({ output = "${m.name}", mode = "${m.w}x${m.h}@${rate}", position = "auto", scale = ${store.monPrefs[m.name]?.scale || '"auto"'} })`);
        }
        monReread.restart();
    }
    function setScale(i, which) {
        const m = which ? mons.find(m => m.name === which) : mon;
        if (!m) return;
        monPref(m.name, { scale: i ? +scales[i] : 0 });
        monitor(m.name);
    }
    function setHz(name, rate) { monPref(name, { hz: rate }); monitor(name); }
    // яркость экрана — просто помним; применяет Prefs через Backlight.setPanel (ему виден services, Rules — нет: цикл импорта)
    function setBri(name, v) { monPref(name, { bri: Math.round(v) }); }
    // дописать настройки монитора: переприсваивание целиком — иначе JsonAdapter не увидит и не запишет файл
    function monPref(name, patch) {
        store.monPrefs = Object.assign({}, store.monPrefs, { [name]: Object.assign({ scale: 0, hz: 0, bri: -1 }, store.monPrefs[name], patch) });
    }
    readonly property var scales: ["auto", "1", "1.25", "1.5", "2"]
    // монитор, «на» котором открыты настройки: Super+I бьёт по фокусу Hyprland (как панель Quick — da56f71).
    // Пусто — главный; DISPLAY правит и показывает именно этот экран
    property string prefsMon: ""
    // главный монитор — как раньше (demonshot, бар, режимы питания): встроенный, а нет его — первый
    readonly property var rates: mon.rates.length ? mon.rates : [60]
    readonly property int refreshHz: nearHz(mon.name)
    readonly property real scale: store.monScale || mon.scale || 1 // что стоит на деле, и при auto
    function windows() {
        const s = store;
        hypr(`hl.config({ general = { gaps_in = ${s.gapsIn}, gaps_out = ${s.gapsOut}, border_size = ${s.border} }, `
           + `decoration = { rounding = ${s.rounding}, blur = { enabled = ${blurOn} }, shadow = { enabled = ${shadowOn} } } })`);
    }
    // ponytail: только вкл/выкл; slam/snap — переопределять кривые из animations.lua
    function motion() { hypr(`hl.config({ animations = { enabled = ${moving} } })`); }
    readonly property var switches: [["alt+shift", "grp:alt_shift_toggle"], ["caps", "grp:caps_toggle"], ["ctrl+shift", "grp:ctrl_shift_toggle"]]
    function input() {
        const s = store;
        hypr(`hl.config({ input = { kb_options = "${switches[s.kbSwitch]?.[1] ?? switches[0][1]}", repeat_delay = ${s.repeatDelay}, repeat_rate = ${s.repeatRate}, `
           + `sensitivity = ${s.sens / 100}, accel_profile = "${s.flat ? "flat" : "adaptive"}", touchpad = { natural_scroll = ${s.natural}, `
           + `tap_to_click = ${s.tap}, disable_while_typing = ${s.typingOff}, scroll_factor = ${s.scroll / 100} } } })`);
    }
    // гибернация есть не везде (нужен swap под resume, zram не годится) — спрашиваем logind. Нет — обычный сон, пункты
    // гибернации прячутся. Ответ пришёл после idle() — переписать конфиг (лок idle() не зовёт, его это не касается)
    property bool canHibernate: false
    property bool idleDone: false
    readonly property bool hibernateOn: store.hibernate && canHibernate
    onCanHibernateChanged: if (idleDone) idle()
    Process {
        running: true
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanSuspendThenHibernate"]
        stdout: StdioCollector { onStreamFinished: root.canHibernate = text.includes('"yes"') }
    }
    // hypridle конфиг на лету не перечитывает: пишем свой и перезапускаем. Тот же текст и hypridle жив — не трогаем,
    // чтобы перезагрузка шелла не сбрасывала счётчик простоя. inhibit_sleep = 3 — сон ждёт, пока лок встанет (сам hypridle
    // так ждёт только hyprlock): иначе лок засыпает недоподнятым, а на пробуждении мониторы моргают — монитор, пропавший
    // в первые ~0.5 с жизни лока, роняет qs (#5)
    function idle() {
        idleDone = true;
        const s = store, dpms = a => `hyprctl dispatch 'hl.dsp.dpms({action = "${a}"})'`;
        const at = (min, on, back) => min ? `\nlistener {\n    timeout = ${min * 60}\n    on-timeout = ${on}${back ? `\n    on-resume = ${back}` : ""}\n}\n` : "";
        const conf = "# demonshot: пишет Rules.idle() из rules.json, руками не править\n"
            + "general {\n    lock_cmd = ~/.config/quickshell/rice/rice lock\n    inhibit_sleep = 3\n"
            + `    before_sleep_cmd = loginctl lock-session\n    after_sleep_cmd = ${dpms("on")}\n}\n`
            + at(s.lockAfter, "loginctl lock-session") + at(s.dpmsAfter, dpms("off"), dpms("on"))
            + at(s.sleepAfter, hibernateOn ? "systemctl suspend-then-hibernate" : "systemctl suspend");
        Quickshell.execDetached(["sh", "-c", 'f="$1/hypridle.conf"; printf %s "$2" | cmp -s - "$f" && pgrep -x hypridle >/dev/null && exit; '
                                       + 'printf %s "$2" > "$f"; pkill -x hypridle; exec hypridle -c "$f"', "sh", dir, conf]);
    }
    function brightness() { Quickshell.execDetached(["brightnessctl", "-q", "set", store.brightness + "%"]); }
    function night() {
        Quickshell.execDetached(["sh", "-c", store.night ? `pkill -x hyprsunset; exec hyprsunset -t ${store.warmth}` : "pkill -x hyprsunset"]);
    }

    // палитра: Theme перекрашивается сам (биндинги на pal), здесь — то, что живёт вне шелла
    function paint() {
        const c = pal.c;
        if (store.paintHypr) {
            const h = c.map(x => x.slice(1));
            hypr(`hl.config({ general = { col = { active_border = { colors = { "rgb(${h[5]})", "rgb(${h[4]})", "rgb(${h[5]})" }, angle = 135 }, `
               + `inactive_border = "rgb(${h[2]})" } }, decoration = { shadow = { color = "rgba(${h[5]}20)" } } })`);
        }
        if (store.paintKitty) {
            kitty.setText([
                ["foreground", c[7]], ["background", c[1]], ["cursor", c[7]], ["cursor_text_color", c[1]],
                ["selection_foreground", c[7]], ["selection_background", c[3]], ["url_color", c[4]],
                ["active_border_color", c[5]], ["inactive_border_color", c[2]],
                ["active_tab_foreground", c[7]], ["active_tab_background", c[5]],
                ["inactive_tab_foreground", c[6]], ["inactive_tab_background", c[1]], ["tab_bar_background", c[0]]
            ].map(([k, v]) => `${k} ${v}`).join("\n") + "\n");
            Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
        }
    }

    // режимы питания, как в caelestia: профиль power-profiles-daemon. ultra сверху — 60 Гц, без анимаций, blur и теней,
    // поверх своих настроек, не трогая их: вышел — вернулись. 0 ultra · 1 saver · 2 balanced · 3 performance.
    // Окна (blur, тени) применяет вызвавший: demonshot — windows(), glyph — Theme.apply() (windows() снял бы его скругление)
    readonly property var modes: [
        { name: "ultra", short: "ULT", what: `power saver · ${rates[0]} hz · still` },
        { name: "saver", short: "ECO", what: "power saver" },
        { name: "balanced", short: "BAL", what: "balanced" },
        { name: "performance", short: "MAX", what: "performance" }
    ]
    readonly property int mode: store.ultra ? 0 : PowerProfiles.profile + 1
    readonly property int modeCount: PowerProfiles.hasPerformanceProfile ? 4 : 3
    function setMode(i) {
        i = Math.max(0, Math.min(modeCount - 1, i));
        const hz0 = hz, moving0 = moving;
        store.ultra = i === 0;
        PowerProfiles.profile = i === 0 ? PowerProfile.PowerSaver : i - 1;
        // монитор — только если герцы правда другие: перенастройка вывода мигает экраном и сбрасывает наведение (панели гаснут)
        if (hz !== hz0) monitor();
        if (moving !== moving0) motion();
    }
    // что стоит на деле: ultra перекрывает настройки — самые низкие герцы экрана, иначе ближайшие к выбранным
    readonly property int hz: store.ultra ? rates[0] : refreshHz
    readonly property bool moving: store.motion && !store.ultra && !store.game
    readonly property bool blurOn: store.blur && !store.ultra && !store.game
    readonly property bool shadowOn: store.shadow && !store.ultra && !store.game

    // старт шелла: всё, кроме яркости (её крутят клавиши и OSD, перетирать на каждом запуске нельзя)
    function applyAll() {
        monitor(); windows(); motion(); night(); paint(); input(); idle();
    }
}
