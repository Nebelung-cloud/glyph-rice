import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// the Dial greeter: Nebelung's SDDM login (config/sddm/glyph) on greetd, so Hyprland needs no SDDM. A disc, like a camera's mode wheel, with a tachometer of
// glyphs inside. The center sits on the bottom edge of the screen: the upper half shows, the scale is a speedometer's semicircle.
// Start — staged power-on, like a car's dashboard: a red dot, the knurl goes round, the glyphs to the stop and the needle
// there and back (a self-test), then the clock and sessions. On the left behind the knurl — a log of the steps.
// Password letters rev the needle, Enter — to the redline while greetd thinks; wrong — a red flash and the needle drops.
// ←→ or the mouse wheel — turn the disc (session), Tab — the next user, Shift+Tab or a click on the name — type your own,
// Esc — clear.
// ↑ — the second ring, power on the right: there ←→ picks, Enter runs, ↓ or Esc — back, a letter — back to the password.
// Outside greetd it's a plain window that shows the look and refuses every password
ShellRoot {
    settings.watchFiles: false

    // cage shows it full screen; anywhere else it is a plain window
    FloatingWindow {
        title: "glyph dial greeter"
        implicitWidth: Quickshell.screens[0]?.width ?? 1920
        implicitHeight: Quickshell.screens[0]?.height ?? 1080
        color: "#000000"

        Rectangle {
            id: root

            anchors.fill: parent
            color: bg

            readonly property color bg: "#000000"
            readonly property color s2: "#1A1A1A"
            readonly property color s3: "#2A2A2A"
            readonly property color mute: "#4A4A4A"
            readonly property color grey: "#8C8C8C"
            readonly property color fg: "#F2F2F2"
            readonly property color red: "#D71921"

            FontLoader { id: doto; source: "fonts/Doto[ROND,wght].ttf" }
            FontLoader { id: grotesk; source: "fonts/SpaceGrotesk-Regular.otf" }
            FontLoader { id: mono; source: "fonts/SpaceMono-Regular.ttf" }

            property date now: new Date()
            property bool blink: true
            Timer { running: true; repeat: true; interval: 500; onTriggered: { root.blink = !root.blink; root.now = new Date(); } }

            // ---- power-on: the steps in turn ----
            property real knurl: 0 // the knurl: the share of the circle covered
            property real test: 0  // self-test: glyphs and needle to the stop and back
            property real face: 0  // clock, sessions, name
            property int step: 0   // how many log steps have finished
            SequentialAnimation {
                running: true
                PauseAnimation { duration: 350 }
                NumberAnimation { target: root; property: "knurl"; to: 1; duration: 700; easing.type: Easing.InOutSine }
                PropertyAction { target: root; property: "step"; value: 1 }
                NumberAnimation { target: root; property: "test"; to: 1; duration: 650; easing.type: Easing.OutCubic }
                PropertyAction { target: root; property: "step"; value: 2 }
                PauseAnimation { duration: 150 }
                NumberAnimation { target: root; property: "test"; to: 0; duration: 600; easing.type: Easing.InOutCubic }
                PropertyAction { target: root; property: "step"; value: 3 }
                NumberAnimation { target: root; property: "face"; to: 1; duration: 500; easing.type: Easing.OutQuart }
                PropertyAction { target: root; property: "step"; value: 4 }
            }

            // ---- tachometer ----
            readonly property int n: 32 // glyphs on the scale, one per letter
            property bool busy: false
            property bool ok: false
            property bool flash: false
            property bool fail: false
            property real wave: 0
            NumberAnimation on wave { running: root.busy; from: 0; to: 1; duration: 600; loops: Animation.Infinite }
            // where the needle is pulled; it catches up on a spring — with overshoot, like a real one. The target mustn't change every frame:
            // Behavior would restart the spring before its step and the needle would stop. So the self-test (step < 3) runs without the spring,
            // and the redline's tremble is added to the angle, not the target
            readonly property real level: ok ? 1 : busy ? 0.94 : Math.max(test, Math.min(pwd.text.length / n, 1))
            property real needle: level
            Behavior on needle { enabled: root.step >= 3; SpringAnimation { spring: 4; damping: 0.26; epsilon: 0.002 } }
            function deg(v) { return -84 + 168 * v; } // 0…1 → an angle from 12 o'clock clockwise, a semicircle above the screen edge

            SequentialAnimation {
                id: denied
                loops: 3
                PropertyAction { target: root; property: "flash"; value: true }
                PauseAnimation { duration: 110 }
                PropertyAction { target: root; property: "flash"; value: false }
                PauseAnimation { duration: 90 }
            }

            // ---- what SDDM used to hand over: sessions, users, the machine's name, the keyboard's lights, the last pick ----
            property var sessions: [] // [{ name, exec }] from /usr/share/wayland-sessions
            property var users: []    // human logins from passwd
            property string host: ""
            property bool caps: false
            property bool num: false
            function indexOr(list, want, fallback) { const i = list.indexOf(want); return i >= 0 ? i : fallback; }
            // last pick lives in the greeter user's home (install.sh makes it)
            FileView {
                id: memo
                path: Quickshell.env("HOME") + "/last.json"
                blockLoading: true
                printErrors: false
                JsonAdapter {
                    id: last
                    property string user: ""
                    property string session: ""
                }
            }
            // your 24 hours and dot grid settings, as a copy made by install.sh
            FileView {
                path: (Quickshell.env("XDG_STATE_HOME") || "/nonexistent") + "/rice/glyph.json"
                blockLoading: true
                printErrors: false
                JsonAdapter {
                    id: prefs
                    property bool clock24: true
                    property bool grid: true
                }
            }
            FileView { id: hostFile; path: "/proc/sys/kernel/hostname"; blockLoading: true; printErrors: false }
            Process {
                running: true
                command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do printf '%s\\t%s\\n' \"$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)\" \"$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-)\"; done"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        // desktop-entry field codes (%U and co) mean nothing to a session
                        const s = text.split("\n").map(l => l.split("\t")).filter(p => p[1]).map(p => ({ name: p[0], exec: p[1].replace(/ ?%[A-Za-z]/g, "") }));
                        const names = s.map(x => x.name);
                        root.sessions = s;
                        root.si = root.indexOr(names, last.session, Math.max(0, names.findIndex(n => /uwsm/i.test(n))));
                    }
                }
            }
            Process {
                running: true
                command: ["sh", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 }'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        root.users = text.split("\n").filter(Boolean);
                        root.ui = root.indexOr(root.users, last.user, 0);
                        if (!user.text && root.users.length) user.text = root.users[root.ui];
                        (user.text ? pwd : user).forceActiveFocus();
                    }
                }
            }
            Process {
                id: leds
                command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | sort -rn | head -1; echo; cat /sys/class/leds/*numlock/brightness 2>/dev/null | sort -rn | head -1"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const v = text.split("\n").filter(Boolean);
                        root.caps = v[0] > 0;
                        root.num = v[1] > 0;
                    }
                }
            }
            Timer { running: true; repeat: true; interval: 1000; onTriggered: leds.running = true }

            // ---- session: the disc position ----
            property int si: 0
            readonly property real gap: 22 // degrees between sessions on the disc
            property real rot: -si * gap
            Behavior on rot { SpringAnimation { spring: 5; damping: 0.35 } }
            function turn(d) { if (sessions.length) si = (si + d + sessions.length) % sessions.length; }

            // ---- the second ring: power. pm — picked from the keyboard, -1 — the ring isn't selected ----
            readonly property var power: [
                { t: "sleep", a: 37, can: true, go: () => Quickshell.execDetached(["systemctl", "suspend"]) },
                { t: "reboot", a: 52, can: true, go: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                { t: "power off", a: 68, can: true, go: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
            ]
            property int pm: -1
            // the next available from i in direction d; none — stays i
            function next(i, d) {
                for (let j = i + d; j >= 0 && j < power.length; j += d) if (power[j].can) return j;
                return i;
            }
            // arrows and Enter on the ring — shared by both fields. true — the key is eaten, the field won't see it
            function key(e) {
                if (pm >= 0) {
                    if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) pm = next(pm, e.key === Qt.Key_Right ? 1 : -1);
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { const p = power[pm]; pm = -1; p.go(); } // woke up — the ring is released, Enter wakes, it doesn't suspend again
                    else if (e.key === Qt.Key_Down || e.key === Qt.Key_Escape) pm = -1;
                    else if (e.key !== Qt.Key_Up) { pm = -1; return false; } // typing — back, the letter goes to the field
                    return true;
                }
                if (e.key === Qt.Key_Up) { pm = next(-1, 1); return pm >= 0; }
                if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) { turn(e.key === Qt.Key_Right ? 1 : -1); return true; }
                return false;
            }

            // ---- who logs in: the name is a field, the list only fills it (Tab). Anyone can be typed, hidden ones too ----
            property int ui: 0
            function pick(d) {
                if (!users.length) return;
                ui = (ui + d + users.length) % users.length;
                user.text = users[ui];
            }

            property bool queued: false
            property string msg // what greetd said: «locked after 3 attempts» from faillock
            function login() {
                if (busy || ok) return;
                const who = user.text.trim();
                if (!who) { user.forceActiveFocus(); return; }
                if (!sessions.length) return refuse("no sessions found");
                if (step < 4) { queued = true; return; } // Enter during the self-test — log in as soon as it ends
                queued = false;
                busy = true;
                fail = false;
                msg = "";
                if (!Greetd.available) return refuse("preview · not running under greetd");
                Greetd.createSession(who);
            }
            onStepChanged: if (step === 4 && queued) login()
            function refuse(why) {
                busy = false;
                fail = true;
                if (why) msg = why; // otherwise keep what greetd said, like how long the account is locked for
                pwd.text = "";
                denied.restart();
                if (Greetd.available && Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
            }
            Connections {
                target: Greetd
                function onAuthMessage(message, error, responseRequired, echoResponse) {
                    if (responseRequired) Greetd.respond(pwd.text);
                    else root.msg = message.trim().replace(/\s*\n\s*/g, " · ");
                }
                function onAuthFailure(message) { root.refuse(""); }
                function onError(error) { console.warn("greetd:", error); root.refuse("login service error · try again"); }
                function onReadyToLaunch() {
                    root.busy = false;
                    root.ok = true;
                    pwd.text = "";
                    last.user = user.text.trim();
                    last.session = root.sessions[root.si]?.name ?? "";
                    memo.writeAdapter();
                    launchT.start();
                }
            }
            // the stage fades out first. greetd joins the command with spaces and runs it through sh, so Exec goes in whole and that shell parses it;
            // it drops the session's output, and systemd-cat keeps it: journalctl -t glyph-session
            Timer { id: launchT; interval: 800; onTriggered: Greetd.launch(["systemd-cat", "-t", "glyph-session", root.sessions[root.si].exec]) }

            // a label: Space Mono caps, tracking .14em, grey
            component Lb: Text {
                property real px: 12
                font { family: mono.name; pixelSize: px; letterSpacing: px * 0.14; capitalization: Font.AllUppercase }
                color: root.grey
            }
            // text along an arc: letters on a circle of radius r, the middle at angle a (degrees from 12 o'clock). Space Mono
            // is monospace — one step for all letters. button — clickable (hit) and whitens under the mouse
            component Arc: Item {
                id: arc
                property string text
                property real r
                property real a
                property real px: 12
                property color color: root.grey
                property bool button: false
                property int hov: 0 // how many letters are under the mouse: leaving one and entering the next arrive in any order
                signal hit
                readonly property string up: text.toUpperCase()
                FontMetrics { id: fm; font { family: mono.name; pixelSize: arc.px } }
                readonly property real adv: fm.advanceWidth("M") + px * 0.14
                Repeater {
                    model: arc.up.split("")
                    Text {
                        required property string modelData
                        required property int index
                        readonly property real b: arc.a + (index + 0.5 - arc.up.length / 2) * arc.adv / arc.r * 180 / Math.PI
                        x: arc.r * Math.sin(b * Math.PI / 180) - width / 2
                        y: -arc.r * Math.cos(b * Math.PI / 180) - height / 2
                        rotation: b
                        text: modelData
                        font { family: mono.name; pixelSize: arc.px }
                        color: arc.button && arc.hov > 0 ? root.fg : arc.color
                        MouseArea {
                            x: (parent.width - arc.adv) / 2
                            y: -8
                            width: arc.adv
                            height: parent.height + 16
                            enabled: arc.button
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: arc.hov += containsMouse ? 1 : -1
                            onClicked: arc.hit()
                        }
                    }
                }
            }
            // a point on a circle of radius r at angle a (degrees from 12 o'clock), the part's center at that point, rotated along the radius
            component Polar: Rectangle {
                property real a
                property real r
                x: r * Math.sin(a * Math.PI / 180) - width / 2
                y: -r * Math.cos(a * Math.PI / 180) - height / 2
                rotation: a
            }

            // a 1920×1080 canvas, stretched to the screen
            Item {
                id: stage
                readonly property real s: Math.min(root.width / 1920, root.height / 1080)
                width: root.width / s
                height: root.height / s
                scale: s
                transformOrigin: Item.TopLeft
                opacity: root.ok ? 0 : 1
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 500 } } }

                MouseArea {
                    anchors.fill: parent
                    property real acc: 0 // a touchpad sends small steps — accumulate up to a click
                    onClicked: pwd.forceActiveFocus()
                    onWheel: w => {
                        acc += w.angleDelta.y;
                        if (Math.abs(acc) < 120) return;
                        root.turn(acc < 0 ? 1 : -1);
                        acc = 0;
                    }
                }

                Image {
                    visible: prefs.grid
                    anchors.fill: parent
                    opacity: root.face
                    fillMode: Image.Tile
                    source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="${root.s2}"/></svg>`)
                }

                // ---- the disc: everything is measured from the center ----
                Item {
                    id: dial
                    x: stage.width / 2
                    y: stage.height

                    // rotates: the knurl on the edge and the sessions
                    Item {
                        rotation: root.rot

                        Repeater {
                            model: 240
                            Polar {
                                required property int index
                                // how far the front has gone past this tick: the front covers the visible half from the left edge to the right
                                readonly property real d: root.knurl - ((index * 1.5 + root.rot) % 360 + 450) % 360 / 180
                                a: index * 1.5
                                r: 760
                                width: 2.5
                                height: 22
                                visible: d >= 0 || root.knurl >= 1
                                color: d < 0.06 && root.knurl < 1 ? root.fg : root.mute
                            }
                        }
                        Repeater {
                            id: labels
                            model: root.sessions
                            Arc {
                                required property var modelData
                                required property int index
                                readonly property real off: Math.abs(((a + root.rot) % 360 + 540) % 360 - 180) // from the mark, 0…180
                                a: index * root.gap
                                r: 712
                                px: 14
                                text: modelData.name
                                color: index === root.si ? root.fg : root.grey
                                opacity: root.face * Math.max(0, 1 - off / 80) * (root.pm < 0 ? 1 : 0.35)
                                button: opacity > 0.2
                                onHit: root.si = index
                            }
                        }
                    }

                    // the disc's mark on top, a hint above it
                    Rectangle { x: -2.5; y: -808; width: 5; height: 24; radius: 2.5; color: root.fg; opacity: root.knurl }
                    Arc {
                        r: 860
                        px: 11
                        color: root.mute
                        opacity: root.face
                        text: `←→ · session      ${root.next(-1, 1) >= 0 ? "↑ · power      " : ""}tab · user      enter · start`
                    }

                    // behind the knurl along the arc: on the left the power-on log bottom to top (a step running blinks, finished — ok) and the machine name,
                    // on the right the layout and power. Power is always visible: not allowed (or --test-mode, no daemon there and all can* are false) —
                    // dark and not clickable
                    Repeater {
                        model: ["dial", "glyph", "needle", "auth"]
                        Arc {
                            required property string modelData
                            required property int index
                            readonly property bool done: root.step > index
                            r: 845
                            a: -76 + index * 13
                            visible: root.step >= index
                            opacity: done || root.blink ? 1 : 0.4
                            text: `0${index + 1} ${modelData} · ${done ? (index === 3 ? "ready" : "ok") : "··"}`
                        }
                    }
                    Arc { r: 845; a: -22; color: root.mute; opacity: root.face; text: hostFile.text().trim() }
                    Arc { r: 845; a: 22; color: root.mute; opacity: root.face; text: (Quickshell.env("XKB_DEFAULT_LAYOUT") || "en").slice(0, 2) }
                    Repeater {
                        model: root.power
                        Arc {
                            required property var modelData
                            required property int index
                            r: 845
                            a: modelData.a
                            button: modelData.can
                            color: !button ? root.mute : root.pm === index ? root.fg : root.grey
                            opacity: root.face
                            text: modelData.t
                            onHit: modelData.go()
                        }
                    }
                    // the second ring's mark: outside the selected one, it travels like the disc's mark
                    Polar {
                        a: root.power[Math.max(0, root.pm)].a
                        r: 885
                        width: 4
                        height: 16
                        radius: 2
                        color: root.fg
                        opacity: root.pm >= 0 ? 1 : 0
                        Behavior on a { SpringAnimation { spring: 5; damping: 0.35 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    // the scale: capsule glyphs, lit up to the needle. Redline — a dip runs over them while greetd thinks
                    Repeater {
                        model: root.n
                        Polar {
                            required property int index
                            readonly property bool lit: index < Math.round(root.needle * root.n)
                            readonly property bool dip: root.busy && Math.abs(index - root.wave * root.n) < 2
                            a: root.deg((index + 0.5) / root.n)
                            r: 610
                            width: 10
                            height: 36
                            radius: 5
                            visible: root.step >= 1 || root.test > 0
                            color: root.flash ? root.red : lit && !dip ? root.fg : root.s3
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }
                    }
                    Repeater {
                        model: 5
                        Lb {
                            required property int index
                            readonly property real a: root.deg(index / 4) * Math.PI / 180
                            x: 658 * Math.sin(a) - width / 2
                            y: -658 * Math.cos(a) - height / 2
                            px: 13
                            text: index * root.n / 4
                            opacity: root.face
                        }
                    }

                    // seconds: an inner arc of dots, the same width as the scale
                    Repeater {
                        model: 60
                        Polar {
                            required property int index
                            a: root.deg(index / 59)
                            r: 320
                            width: 5
                            height: 5
                            radius: 2.5
                            opacity: root.knurl
                            color: index === root.now.getSeconds() ? root.fg : index < root.now.getSeconds() ? root.mute : root.s2
                        }
                    }

                    // the needle: from the seconds ring to the scale, a red tip
                    Item {
                        rotation: root.deg(root.needle + (root.busy ? 0.015 * Math.sin(root.wave * 4 * Math.PI) : 0))
                        opacity: root.step >= 1 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Rectangle {
                            x: -2
                            y: -578
                            width: 4
                            height: 230
                            radius: 2
                            color: root.fg
                            Rectangle { width: 4; height: 44; radius: 2; color: root.red }
                        }
                    }

                    // the first thing to light up
                    Rectangle {
                        x: -8; y: -200; width: 16; height: 16; radius: 8
                        color: root.red
                        opacity: 1 - root.face
                        NumberAnimation on scale { from: 0; to: 1; duration: 300; easing.type: Easing.OutBack }
                    }

                    Row {
                        x: -width / 2
                        y: -262
                        opacity: root.face
                        Repeater {
                            // "h" without AP in the format is still 0…23 in Qt — 12-hour is computed by hand
                            model: [prefs.clock24 ? Qt.formatTime(root.now, "hh") : String(root.now.getHours() % 12 || 12), ":", Qt.formatTime(root.now, "mm")]
                            Text {
                                required property string modelData
                                required property int index
                                text: modelData
                                font { family: doto.name; pixelSize: 130; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
                                topPadding: -0.175 * font.pixelSize
                                bottomPadding: topPadding
                                color: root.fg
                                opacity: index === 1 && !root.blink ? 0.2 : 1
                            }
                        }
                    }
                    Lb {
                        x: -width / 2
                        y: -128
                        px: 12
                        text: Qt.locale("en_US").toString(root.now, "ddd · d MMM")
                        opacity: root.face
                    }

                    // under the clock — who's logging in and what's happening
                    TextInput {
                        id: user
                        x: -width / 2
                        y: -98
                        width: 360
                        height: 30
                        opacity: root.face
                        horizontalAlignment: TextInput.AlignHCenter
                        font { family: grotesk.name; pixelSize: 24 }
                        color: root.fg
                        selectionColor: root.s3
                        selectedTextColor: root.fg
                        Lb { anchors.centerIn: parent; visible: !parent.text; text: "user" }
                        onActiveFocusChanged: if (activeFocus) selectAll() // started typing — the name is replaced whole
                        onAccepted: pwd.forceActiveFocus()
                        Keys.onPressed: e => {
                            if (root.pm < 0 && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) return; // the field is visible — arrows move the cursor, not the disc
                            if (root.key(e)) e.accepted = true;
                            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { pwd.forceActiveFocus(); e.accepted = true; }
                        }
                    }
                    Lb {
                        x: -width / 2
                        y: -52
                        px: 12
                        opacity: root.face
                        color: root.flash || root.fail ? root.red : root.grey
                        text: root.ok ? "welcome" : root.busy ? "ignition…" : root.fail ? root.msg || "denied · try again"
                            : root.pm >= 0 ? `enter · ${root.power[root.pm].t}      ↓ · back`
                            : user.activeFocus ? "type user · tab"
                            : pwd.text ? `${pwd.text.length} · enter to start` : "type password"
                    }
                }

                // input — a real TextInput (layouts, IME), just invisible
                TextInput {
                    id: pwd
                    width: 1
                    height: 1
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    onTextEdited: root.fail = false
                    onAccepted: root.login()
                    // no cursor needed in an invisible field — arrows belong to the disc and the ring
                    Keys.onPressed: e => {
                        if (root.key(e)) e.accepted = true;
                        else if (e.key === Qt.Key_Escape) { text = ""; e.accepted = true; }
                        else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                            if (e.key === Qt.Key_Tab && root.users.length > 1) root.pick(1);
                            else user.forceActiveFocus(); // one in the list or Shift+Tab — type a name
                            e.accepted = true;
                        }
                    }
                }

                // corners on top: the mark on the left, indicators on the right — a dot is lit while the key is on
                Column {
                    x: 44
                    y: 36
                    spacing: 6
                    opacity: root.face
                    Text {
                        text: "GLYPH"
                        font { family: doto.name; pixelSize: 34; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
                        topPadding: -0.175 * font.pixelSize
                        bottomPadding: topPadding
                        color: root.fg
                    }
                    Lb { px: 11; text: "login" }
                }
                Row {
                    anchors { right: parent.right; rightMargin: 44 }
                    y: 40
                    spacing: 28
                    opacity: root.face
                    Repeater {
                        model: [["caps", root.caps], ["num", root.num]]
                        Row {
                            required property var modelData
                            spacing: 10
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.modelData[1] ? root.fg : root.s3 }
                            Lb { px: 11; text: parent.modelData[0]; color: parent.modelData[1] ? root.fg : root.grey }
                        }
                    }
                }

            }
        }
    }
}
