import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.settings

// dock: нижняя панель приложений в аутентичном стиле Nothing OS (Glyph)
// Автоскрытие (auto-hide), увеличенный размер (74 px), аутентичные круглые иконки Nothing OS (глифы + Dm dot-matrix)
PanelWindow {
    id: root

    signal markClicked
    signal deckClicked

    // Состояние автоскрытия
    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: Theme.t
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.glide
        }
    }

    // Глифы для известных приложений (в точности как в Launcher.qml Nothing OS)
    readonly property var glyphs: [
        ["zen", "\u{F0239}"], ["firefox", "\u{F0239}"], ["chrom", "\u{F059F}"], ["kitty", "\u{F018D}"], ["foot", "\u{F018D}"],
        ["spotify", "\u{F04C7}"], ["telegram", "\u{F2C6}"], ["codium", "\u{F0A1E}"], ["code", "\u{F0A1E}"], ["steam", "\u{F04D3}"],
        ["discord", "\u{F066F}"], ["vesktop", "\u{F066F}"], ["equibop", "\u{F066F}"], ["calculator", "\u{F00EC}"], ["calendar", "\u{F00ED}"],
        ["camera", "\u{F0100}"], ["thunar", "\u{F024B}"], ["nautilus", "\u{F024B}"], ["files", "\u{F024B}"], ["gimp", "\u{F02E9}"],
        ["mail", "\u{F01EE}"], ["btop", "\u{F035B}"], ["monitor", "\u{F035B}"], ["obsidian", "\u{F082E}"], ["settings", "\u{F0493}"],
        ["pavucontrol", "\u{F057E}"], ["mpv", "\u{F040A}"], ["vlc", "\u{F040A}"], ["clash", "\u{F0483}"], ["torrent", "\u{F01DA}"]
    ]

    function findGlyph(key) {
        if (!key) return "";
        const k = key.toLowerCase();
        return glyphs.find(g => k.includes(g[0]))?.[1] ?? "";
    }

    // Закреплённые приложения
    property var pinned: [
        {
            id: "brave-browser",
            name: "Brave Browser",
            exec: "brave-browser",
            icon: Quickshell.iconPath("brave-browser", true) || "file:///usr/share/icons/hicolor/48x48/apps/brave-browser.png",
            glyph: "" // Использует точечный шейдер Dm для льва Brave (как в лаунчере)
        },
        {
            id: "org.gnome.Nautilus",
            name: "Files",
            exec: "nautilus",
            icon: Quickshell.iconPath("org.gnome.Nautilus", true) || "file:///usr/share/icons/Yaru/48x48/apps/org.gnome.Nautilus.png",
            glyph: "\u{F024B}"
        },
        {
            id: "terminal",
            name: "Terminal",
            exec: "kitty",
            icon: Quickshell.iconPath("kitty", true) || "file:///usr/share/icons/hicolor/scalable/apps/kitty.svg",
            glyph: "\u{F018D}"
        },
        {
            id: "antigravity",
            name: "Antigravity IDE",
            exec: "antigravity",
            icon: Quickshell.iconPath("antigravity-ide", true) || (Quickshell.env("HOME") ? "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png" : ""),
            glyph: "" // Использует точечный шейдер Dm (как в лаунчере)
        },
        {
            id: "discord",
            name: "Discord",
            exec: "discord",
            icon: Quickshell.iconPath("discord", true) || "image://icon/discord",
            glyph: "\u{F066F}"
        },
        {
            id: "org.gnome.Software",
            name: "App Center",
            exec: "gnome-software",
            icon: Quickshell.iconPath("org.gnome.Software", true) || "file:///usr/share/icons/Yaru/48x48/apps/org.gnome.Software.png",
            glyph: "\u{F0493}"
        }
    ]

    function resolveIcon(cls) {
        if (!cls) return "";
        const c = cls.toLowerCase();
        const iconName = DesktopEntries.heuristicLookup(cls)?.icon;
        if (iconName) {
            const p = Quickshell.iconPath(iconName, true);
            if (p) return p;
            return "image://icon/" + iconName;
        }

        const home = Quickshell.env("HOME") || "";
        if (c.includes("brave")) return Quickshell.iconPath("brave-browser", true) || "file:///usr/share/icons/hicolor/48x48/apps/brave-browser.png";
        if (c.includes("nautilus") || c.includes("files")) return Quickshell.iconPath("org.gnome.Nautilus", true) || "file:///usr/share/icons/Yaru/48x48/apps/org.gnome.Nautilus.png";
        if (c.includes("kitty")) return Quickshell.iconPath("kitty", true) || "file:///usr/share/icons/hicolor/scalable/apps/kitty.svg";
        if (c.includes("ptyxis")) return Quickshell.iconPath("org.gnome.Ptyxis", true) || "file:///usr/share/icons/Yaru/48x48/apps/org.gnome.Ptyxis.png";
        if (c.includes("antigravity")) return Quickshell.iconPath("antigravity-ide", true) || (home ? "file://" + home + "/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png" : "");
        if (c.includes("discord")) return Quickshell.iconPath("discord", true) || "image://icon/discord";

        return "image://icon/" + cls;
    }

    // Список элементов дока: закреплённые + все открытые окна
    readonly property var items: {
        const toplevels = Hyprland.toplevels.values;
        const activeT = ToplevelManager.activeToplevel;
        const activeApp = (activeT?.appId || "").toLowerCase();
        const res = [];
        const seen = new Set();

        // 1. Закреплённые приложения
        for (const p of pinned) {
            const pid = p.id.toLowerCase();
            const matching = toplevels.filter(t => {
                const cls = (t.lastIpcObject?.class || "").toLowerCase();
                const initCls = (t.lastIpcObject?.initialClass || "").toLowerCase();
                return cls.includes(pid) || pid.includes(cls) || initCls.includes(pid) ||
                       (pid.includes("terminal") && (cls.includes("kitty") || cls.includes("ptyxis"))) ||
                       (pid.includes("nautilus") && (cls.includes("files") || cls.includes("nautilus")));
            });

            const isRunning = matching.length > 0;
            const isActive = matching.some(t => {
                const cls = (t.lastIpcObject?.class || "").toLowerCase();
                return (activeApp && (cls.includes(activeApp) || activeApp.includes(cls))) ||
                       (t.lastIpcObject?.focusHistoryID === 0);
            });
            const curTitle = matching.find(t => t.lastIpcObject?.focusHistoryID === 0)?.title || matching[0]?.title || "";

            res.push({
                id: p.id,
                name: p.name,
                exec: p.exec,
                icon: p.icon,
                glyph: p.glyph || root.findGlyph(p.id + " " + p.name),
                pinned: true,
                running: isRunning,
                active: isActive,
                count: matching.length,
                title: curTitle,
                windows: matching
            });
            matching.forEach(t => seen.add(t));
        }

        // 2. Открытые окна, не входящие в закреплённые
        for (const t of toplevels) {
            if (seen.has(t)) continue;
            const cls = t.lastIpcObject?.class || "app";
            const clsLower = cls.toLowerCase();
            const existing = res.find(r => !r.pinned && r.id === clsLower);
            const isThisActive = (t.lastIpcObject?.focusHistoryID === 0) || (activeApp && clsLower.includes(activeApp));

            if (existing) {
                existing.count++;
                existing.windows.push(t);
                if (isThisActive) {
                    existing.active = true;
                    existing.title = t.title || existing.name;
                }
            } else {
                res.push({
                    id: clsLower,
                    name: t.title ? t.title.split(" - ").pop().split(" — ").pop() : cls,
                    exec: clsLower,
                    icon: resolveIcon(cls),
                    glyph: root.findGlyph(cls + " " + (t.title || "")),
                    pinned: false,
                    running: true,
                    active: isThisActive,
                    count: 1,
                    title: t.title || cls,
                    windows: [t]
                });
            }
        }
        return res;
    }

    // Активация окна или запуск
    function activateItem(it) {
        if (it.running && it.windows.length > 0) {
            if (it.active && it.windows.length > 1) {
                const curIdx = it.windows.findIndex(w => w.lastIpcObject?.focusHistoryID === 0);
                const nextIdx = (curIdx + 1) % it.windows.length;
                Hyprland.dispatch(`focuswindow address:0x${it.windows[nextIdx].address}`);
            } else {
                Hyprland.dispatch(`focuswindow address:0x${it.windows[0].address}`);
            }
        } else if (it.exec) {
            Quickshell.execDetached(["sh", "-c", it.exec]);
        }
        leave.restart();
    }

    property var hoverItem: null

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Math.ceil(150 * Theme.s)
    color: "transparent"
    WlrLayershell.namespace: "glyph-dock"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore

    // Маска: когда скрыт — активна только тонкая 6 px полоса у нижнего края экрана
    // Когда показан — активно всё окно дока вместе с подсказками
    mask: Region {
        y: root.shown ? 0 : root.height - 6
        width: root.width
        height: root.shown ? root.height : 6
    }

    Timer { id: dwell; interval: 80; onTriggered: root.shown = true }
    Timer { id: leave; interval: 350; onTriggered: root.shown = false }

    Stage {
        // Зона наведения у нижнего края экрана
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    leave.stop();
                    dwell.restart();
                } else {
                    dwell.stop();
                    leave.restart();
                }
            }
        }

        // Всплывающая подсказка над иконкой в стиле Nothing OS
        Rectangle {
            id: tip
            z: 100
            x: pill.x + (pill.width - width) / 2
            y: pill.y - height - 12
            opacity: (root.hoverItem && root.shown) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            width: tipCol.implicitWidth + 32
            height: tipCol.implicitHeight + 16
            radius: Theme.corner(18)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }

            Column {
                id: tipCol
                anchors.centerIn: parent
                spacing: 3
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font { family: Theme.dot; pixelSize: 15 }
                    color: Theme.fg
                    text: root.hoverItem ? root.hoverItem.name : ""
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!root.hoverItem && root.hoverItem.running && !!root.hoverItem.title && root.hoverItem.title !== root.hoverItem.name
                    width: Math.min(360, implicitWidth)
                    elide: Text.ElideRight
                    font { family: Theme.mono; pixelSize: 11 }
                    color: Theme.grey
                    text: root.hoverItem ? root.hoverItem.title : ""
                }
            }
        }

        // Капсула дока (увеличенный размер 74 px с фирменным скруглением Nothing OS)
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 14 + (1 - root.t) * (height + 24)
            opacity: root.t

            height: 74
            width: row.width + 28
            radius: Theme.corner(37)
            color: Theme.s1
            border { width: 1.5; color: Theme.s2 }

            Row {
                id: row
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Кнопка Launcher: фирменный знак Nothing OS из 16 точек
                Item {
                    id: markBtn
                    width: 54
                    height: 54
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.corner(27)
                        scale: markArea.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        color: markArea.containsMouse ? Theme.s2 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                    }
                    Ring {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        n: 16
                        dot: 3.2
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 9
                        height: 9
                        radius: 4.5
                        color: !Sys.live ? Theme.fg : Qt.colorEqual(Theme.accent, Theme.fg) ? Theme.red : Theme.accent
                    }
                    MouseArea {
                        id: markArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverItem = { name: "All Apps (Launcher)", running: false }
                        onExited: if (root.hoverItem?.name === "All Apps (Launcher)") root.hoverItem = null
                        onClicked: root.markClicked()
                    }
                }

                // Разделитель
                Rectangle {
                    width: 1.5
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.s3
                    radius: 1
                }

                // Приложения в фирменном стиле Nothing OS: круглые монохромные диски с аутентичными глифами и точечным шейдером
                Repeater {
                    model: root.items

                    Item {
                        id: cell
                        required property var modelData
                        width: 54
                        height: 58
                        anchors.verticalCenter: parent.verticalCenter

                        // Круглый Nothing OS диск приложения (как в Launcher.qml)
                        Rectangle {
                            id: disc
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            width: 48
                            height: 48
                            radius: 24
                            scale: cellArea.containsMouse ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            color: cell.modelData.active && !!cell.modelData.glyph
                                ? Theme.fg
                                : (cellArea.containsMouse ? Theme.s3 : Theme.s2)
                            border.width: 1
                            border.color: cell.modelData.active
                                ? (cell.modelData.glyph ? Theme.fg : Theme.red)
                                : Theme.s3
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                            Behavior on border.color { ColorAnimation { duration: Theme.t } }

                            // 1. Иконка-глиф (Nerd Font в стиле Nothing OS)
                            Icon {
                                anchors.centerIn: parent
                                visible: !!cell.modelData.glyph
                                text: cell.modelData.glyph
                                font.pixelSize: 26
                                color: cell.modelData.active ? Theme.ink : Theme.fg
                                Behavior on color { ColorAnimation { duration: Theme.t } }
                            }

                            // 2. Иконка через точечный шейдер Dm (Nothing OS Dot-Matrix LED)
                            Image {
                                id: img
                                anchors.centerIn: parent
                                visible: !cell.modelData.glyph && status === Image.Ready
                                width: 32
                                height: 32
                                source: cell.modelData.icon || ""
                                sourceSize: Qt.size(32, 32)
                                asynchronous: true
                                smooth: true
                                retainWhileLoading: true
                                layer.enabled: true
                                layer.effect: Dm { step: 2.2 }
                            }

                            // 3. Фоллбэк, если иконка не загрузилась
                            Icon {
                                anchors.centerIn: parent
                                visible: !cell.modelData.glyph && img.status !== Image.Ready
                                text: "\u{F018D}"
                                font.pixelSize: 24
                                color: Theme.fg
                            }
                        }

                        // Индикатор работы (Красная пилюля Nothing Red для активного окна, белая точка для открытого)
                        Item {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: cell.modelData.active ? 16 : 5
                            height: 4
                            visible: cell.modelData.running

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: cell.modelData.active ? Theme.red : Theme.fg
                                opacity: cell.modelData.active ? 1.0 : 0.75
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.t
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Theme.glide
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: Theme.t } }
                            }
                        }

                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoverItem = cell.modelData
                            onExited: if (root.hoverItem?.id === cell.modelData.id) root.hoverItem = null
                            onClicked: root.activateItem(cell.modelData)
                        }
                    }
                }

                // Разделитель
                Rectangle {
                    width: 1.5
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.s3
                    radius: 1
                }

                // Кнопка Deck (Погода и системные виджеты)
                Item {
                    id: deckBtn
                    width: 68
                    height: 54
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.corner(27)
                        scale: deckArea.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        color: deckArea.containsMouse ? Theme.s2 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.now ? Weather.glyph(Weather.now.code, Weather.now.day) : "\u{F0590}"
                            font.pixelSize: 21
                            color: Theme.fg
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font { family: Theme.dot; pixelSize: 16 }
                            color: Theme.fg
                            text: Weather.now ? `${Math.round(Weather.now.temp)}°` : "··"
                        }
                    }

                    MouseArea {
                        id: deckArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverItem = { name: "Deck (Weather & System)", running: false }
                        onExited: if (root.hoverItem?.name === "Deck (Weather & System)") root.hoverItem = null
                        onClicked: root.deckClicked()
                    }
                }
            }
        }
    }
}
