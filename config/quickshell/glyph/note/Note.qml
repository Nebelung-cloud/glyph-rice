import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    property string dir: ""
    property var notes: []
    property string query: ""
    property string listedQuery: ""
    property bool refreshPending: false
    property int sel: 0
    property string cur: ""
    property string version: ""
    property string savedText: ""
    property bool replacingText: false
    property bool booted: false
    property var job: null
    property var transition: null
    property string status: ""
    property bool failed: false

    readonly property var view: (listedQuery === query ? notes : [])
        .map(n => ({ name: n.name, title: n.title, mtime: n.mtime, version: n.version, bucket: bucket(n.mtime) }))
    readonly property int words: ed.text.trim() ? ed.text.trim().split(/\s+/).length : 0

    property bool shown: false
    property bool drawer: false
    property bool reminderMenuOpen: false

    NoteReminders { id: reminders; directory: root.dir }
    readonly property bool reminderPending: reminders.pending(cur)
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    property real dt: drawer ? 1 : 0
    Behavior on dt { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function open() { shown = true; refresh(); }
    function close() {
        hide();
        if (!booted || transition) return;
        autosave.stop();
        advance();
    }
    function hide() { shown = false; drawer = false; reminderMenuOpen = false; input.text = ""; }

    function toggleReminderMenu() {
        if (reminderMenuOpen) {
            closeReminderMenu();
            return;
        }
        drawer = false;
        reminderMenuOpen = true;
        if (root.reminderPending) reminderMenu.forceActiveFocus();
        else reminderMinutes.forceActiveFocus();
    }

    function closeReminderMenu() {
        reminderMenuOpen = false;
        ed.forceActiveFocus();
    }

    function setReminder() {
        if (!reminderMinutes.acceptableInput) return;
        if (!booted || transition || !ed.text.trim()) return;
        const minutes = Number(reminderMinutes.text);
        closeReminderMenu();
        request("remind", { minutes });
    }
    function toggle() { shown ? close() : open(); }
    function history() {
        if (drawer) { drawer = false; ed.forceActiveFocus(); }
        else { drawer = true; input.forceActiveFocus(); }
    }

    function helper(action, args) {
        return ["python3", Quickshell.shellPath("note/notes.py"), action, ...args];
    }

    function notice(message, error) {
        status = message;
        failed = error;
        statusTimer.stop();
        if (!error) statusTimer.start();
    }

    function start(action, args, payload) {
        job = { action, name: args[0] || "", payload, copy: action === "save" && !args[0] && !!cur };
        io.command = helper(action, action === "directory" ? [] : [dir, ...args]);
        io.stdinEnabled = action === "save";
        io.running = true;
    }

    function request(action, note) {
        if (!booted || transition || (job && job.action !== "save" && job.action !== "trash")) return;
        if (job && job.action === "trash" && action === "trash") return;
        transition = { action, note };
        autosave.stop();
        advance();
    }

    // Смена заметки ждёт завершения записи. При ошибке редактор сохраняет исходный буфер.
    function advance() {
        if (job || !booted) return;
        const next = transition;
        if (next?.action === "trash" && next.note.name === cur) {
            start("trash", [cur, version]);
            return;
        }
        if (ed.text !== savedText) {
            if (ed.text.trim()) {
                start("save", [cur, version], ed.text);
                return;
            }
            if (cur) {
                start("trash", [cur, version]);
                return;
            }
        }
        if (!next) return;
        if (next.action === "remind") {
            transition = null;
            reminders.schedule(cur, next.note.minutes);
            notice("reminder set", false);
            return;
        }
        if (next.action === "read" && next.note.name !== cur) {
            start("read", [next.note.name]);
            return;
        }
        if (next.action === "trash") {
            start("trash", [next.note.name, next.note.version]);
            return;
        }
        if (next.action === "copy") {
            start("copy", [next.note.name]);
            return;
        }
        transition = null;
        if (next.action === "fresh") setEditor("", "", "");
        if (shown) leaveHistory();
    }

    function setEditor(name, revision, text) {
        replacingText = true;
        cur = name;
        version = revision;
        ed.text = text;
        savedText = ed.text;
        ed.cursorPosition = 0;
        flick.contentY = 0;
        replacingText = false;
    }

    function leaveHistory() {
        drawer = false;
        input.text = "";
        ed.forceActiveFocus();
    }

    function finish(code, output) {
        const completed = job;
        job = null;
        let data;
        if (code === 0) {
            try { data = JSON.parse(output); }
            catch (_) { code = 1; }
        }
        if (code !== 0) {
            transition = null;
            autosave.stop();
            if (completed.action === "directory") notice("notes folder unavailable", true);
            else if (code === 3 && ed.text !== savedText && ed.text.trim())
                notice("file changed · ctrl+shift+s to save a copy", true);
            else if (code === 3) notice("file changed on disk", true);
            else if (code === 4) notice("trash requires gio", true);
            else notice(completed.action + " failed", true);
            return;
        }
        switch (completed.action) {
        case "directory":
            dir = data;
            refresh();
            return;
        case "read":
            setEditor(completed.name, data.version, data.text);
            transition = null;
            if (shown) leaveHistory();
            return;
        case "save":
            cur = data.name;
            version = data.version;
            savedText = completed.payload;
            notice(completed.copy ? "saved a copy" : "saved", false);
            refresh();
            break;
        case "trash":
            reminders.cancel(completed.name);
            if (cur === completed.name) setEditor("", "", "");
            if (transition?.action === "trash" && transition.note.name === completed.name) transition = null;
            notice("moved to trash", false);
            refresh();
            break;
        case "copy":
            transition = null;
            copyText(data.text);
            return;
        }
        if (transition || !autosave.running) Qt.callLater(advance);
    }

    function saveCopy() {
        if (!booted || job || transition || !ed.text.trim()) return;
        autosave.stop();
        start("save", ["", ""], ed.text);
    }

    function load(note) { request("read", note); }
    function fresh() { request("fresh"); }
    function burn(note) { request("trash", note); }
    function copyNote(note) {
        if (transition) return;
        if (note.name === cur) copyText(ed.text);
        else request("copy", note);
    }

    function copyText(text) {
        if (clipboard.running) return;
        clipboard.payload = text;
        clipboard.stdinEnabled = true;
        clipboard.running = true;
    }

    function refresh() {
        if (!dir) return;
        if (lister.running) {
            refreshPending = true;
            return;
        }
        refreshPending = false;
        lister.query = query;
        lister.command = helper("list", [dir, query]);
        lister.running = true;
    }

    function finishList(code, output) {
        if (code === 0 && lister.query === query) {
            try {
                notes = JSON.parse(output);
                listedQuery = query;
            } catch (_) { code = 1; }
        }
        if (code !== 0) notice("notes list unavailable", true);
        if (!booted && lister.query === query) {
            booted = true;
            if (code === 0 && notes.length && query === "") load(notes[0]);
        }
        if (refreshPending || lister.query !== query) Qt.callLater(refresh);
    }

    function when(ts) {
        const d = new Date(ts * 1000), now = new Date();
        return d.toDateString() === now.toDateString()
            ? Qt.formatDateTime(d, "HH:mm") : Qt.formatDateTime(d, "dd.MM HH:mm");
    }

    function bucket(ts) {
        const date = new Date(ts * 1000);
        const cutoff = new Date();
        cutoff.setHours(0, 0, 0, 0);
        if (date >= cutoff) return "today";
        cutoff.setDate(cutoff.getDate() - 1);
        if (date >= cutoff) return "yesterday";
        cutoff.setDate(cutoff.getDate() - 6);
        if (date >= cutoff) return "last week";
        cutoff.setDate(cutoff.getDate() - 23);
        if (date >= cutoff) return "last month";
        return ">30 days";
    }

    onDrawerChanged: {
        if (!drawer) return;
        reminderMenuOpen = false;
        if (query === "") sel = Math.max(0, view.findIndex(n => n.name === cur));
        rows.positionViewAtIndex(sel, ListView.Contain);
    }
    onViewChanged: sel = Math.max(0, Math.min(sel, view.length - 1))
    onSelChanged: if (view.length) rows.positionViewAtIndex(sel, ListView.Contain)
    onQueryChanged: searchTimer.restart()

    Process {
        id: io
        stdout: StdioCollector { id: reply }
        onStarted: {
            if (root.job.action === "save") {
                write(root.job.payload);
                stdinEnabled = false;
            }
        }
        onExited: code => root.finish(code, reply.text)
    }

    Process {
        id: lister
        property string query: ""
        stdout: StdioCollector { id: listing }
        onExited: code => root.finishList(code, listing.text)
    }

    Process {
        id: clipboard
        command: ["wl-copy"]
        property string payload: ""
        onStarted: { write(payload); stdinEnabled = false; }
        onExited: code => root.notice(code === 0 ? "copied" : "copy failed", code !== 0)
    }

    Timer { id: searchTimer; interval: 150; onTriggered: root.refresh() }
    Timer { id: autosave; interval: 600; onTriggered: root.advance() }
    Timer { id: statusTimer; interval: 1600; onTriggered: root.status = "" }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-note"

    onShownChanged: if (shown) ed.forceActiveFocus()
    Component.onCompleted: start("directory", [])

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    component Chip: Rectangle {
        id: c
        property string label
        opacity: enabled ? 1 : 0.45
        signal tapped
        width: lab.implicitWidth + 30
        height: 42
        radius: 21
        color: hov.hovered ? Theme.fg : Theme.s3
        Behavior on color { ColorAnimation { duration: 150 } }
        Lb { id: lab; anchors.centerIn: parent; text: c.label; px: 10; color: hov.hovered ? Theme.ink : Theme.grey }
        TapHandler { onTapped: c.tapped() }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    }

    Stage {
        id: stage

        Rectangle {
            id: card
            x: (stage.width - width) / 2
            // по центру экрана с учётом хинтов под карточкой; при закрытии — на 24 px ниже (выезд)
            y: (stage.height - height - 40) / 2 + 24 * (1 - root.t)
            width: 1008
            height: Math.min(stage.height - 280, 684)
            opacity: root.t
            radius: Theme.corner(44)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            clip: true

            MouseArea { anchors.fill: parent }

            // пилюля поиска как у Win+V: лупа, поле, × очистки и две пилюли в одной строке
            Rectangle {
                id: pill
                x: 30
                y: 26
                width: parent.width - 60
                height: 62
                radius: 31
                color: Theme.s2

                Icon { id: lens; x: 22; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey; font.pixelSize: 20 }

                TextInput {
                    id: input
                    anchors { left: lens.right; leftMargin: 14; right: clearBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    font { family: Theme.ui; pixelSize: 20 }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    selectedTextColor: Theme.fg
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.accent
                        visible: input.activeFocus
                        Timer {
                            running: input.activeFocus
                            interval: 520
                            repeat: true
                            onRunningChanged: if (running) parent.opacity = 1
                            onTriggered: parent.opacity = 1 - parent.opacity
                        }
                    }
                    Text {
                        visible: !input.text
                        x: 2
                        text: "Search notes"
                        font: input.font
                        color: Theme.mute
                    }
                    onActiveFocusChanged: if (activeFocus) root.reminderMenuOpen = false
                    onTextChanged: {
                        root.query = text;
                        root.sel = 0;
                        if (text.length && !root.drawer) root.drawer = true;
                    }
                    Keys.onPressed: e => {
                        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
                        if (ctrl && e.key === Qt.Key_H) {
                            root.history();
                        } else if (e.key === Qt.Key_Escape) {
                            if (input.text) input.text = "";
                            else { root.drawer = false; ed.forceActiveFocus(); }
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (root.view[root.sel]) root.load(root.view[root.sel]);
                        } else if (e.key === Qt.Key_Up) {
                            root.sel = Math.max(0, root.sel - 1);
                        } else if (e.key === Qt.Key_Down) {
                            root.sel = Math.max(0, Math.min(root.view.length - 1, root.sel + 1));
                        } else if (root.drawer && (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)) {
                            rows.forceActiveFocus();
                        } else return;
                        e.accepted = true;
                    }
                }

                Rectangle {
                    id: clearBtn
                    anchors { right: chips.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 34
                    height: 34
                    radius: 17
                    visible: input.text.length > 0
                    color: clearHov.hovered ? Theme.fg : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font { family: Theme.ui; pixelSize: 20; weight: Font.Medium }
                        color: clearHov.hovered ? Theme.ink : Theme.grey
                    }
                    TapHandler { onTapped: { input.text = ""; input.forceActiveFocus(); } }
                    HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                }

                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Chip {
                        label: root.reminderPending ? reminders.remaining(root.cur) : "remind"
                        enabled: root.booted && !root.transition && (root.reminderPending || !!ed.text.trim())
                        onTapped: root.toggleReminderMenu()
                    }
                    Chip { label: "+ new"; onTapped: root.fresh() }
                    Chip { label: "notes"; onTapped: root.history() }
                }
            }

            // прокрутка: TextEdit сам не листается — держим его в Flickable и держим каретку в кадре,
            // колесо/тачпад листают заметку целиком
            Flickable {
                id: flick
                anchors { fill: parent; leftMargin: 42; rightMargin: 42; topMargin: 114; bottomMargin: 64 }
                contentWidth: width
                contentHeight: ed.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function ensureVisible() {
                    const r = ed.positionToRectangle(ed.cursorPosition);
                    const pad = 8;
                    if (r.y < contentY + pad) contentY = Math.max(0, r.y - pad);
                    else if (r.y + r.height > contentY + height - pad)
                        contentY = Math.min(Math.max(0, contentHeight - height), r.y + r.height - height + pad);
                }

                TextEdit {
                    id: ed
                    width: flick.width
                    height: Math.max(flick.height, ed.contentHeight)
                    focus: true
                    readOnly: !root.booted || root.transition !== null || root.job?.action === "trash"
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    selectByMouse: true
                    persistentSelection: true
                    color: Theme.fg
                    selectionColor: Theme.s3
                    selectedTextColor: Theme.fg
                    font { family: Theme.ui; pixelSize: 23 }
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.accent
                        visible: ed.activeFocus
                        Timer {
                            running: ed.activeFocus
                            interval: 520
                            repeat: true
                            onRunningChanged: if (running) parent.opacity = 1
                            onTriggered: parent.opacity = 1 - parent.opacity
                        }
                    }
                    // клик по редактору — история закрывается и фокус возвращается к тексту
                    onActiveFocusChanged: if (activeFocus) {
                        root.drawer = false;
                        root.reminderMenuOpen = false;
                    }
                    onCursorPositionChanged: flick.ensureVisible()
                    Keys.onPressed: e => {
                        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
                        if (e.key === Qt.Key_Escape) {
                            if (root.drawer) root.drawer = false;
                            else root.close();
                        } else if (ctrl && e.key === Qt.Key_Space) {
                            root.fresh();
                        } else if (ctrl && e.key === Qt.Key_S) {
                            if (e.modifiers & Qt.ShiftModifier) root.saveCopy();
                            else root.advance();
                        } else if (ctrl && e.key === Qt.Key_H) {
                            root.history();
                        } else if (e.key === Qt.Key_Tab && !ed.readOnly) {
                            ed.insert(ed.cursorPosition, "    ");
                        } else return;
                        e.accepted = true;
                    }
                    onTextChanged: {
                        if (!root.replacingText) autosave.restart();
                        flick.ensureVisible();
                    }
                }
            }

            Text {
                x: 44
                y: 116
                visible: ed.text.length === 0
                text: "start typing…"
                textFormat: Text.PlainText
                font: ed.font
                color: Theme.mute
            }

            // сколько слов в заметке — мелкая деталь внизу справа, под редактором
            Lb {
                anchors { right: parent.right; rightMargin: 42; bottom: parent.bottom; bottomMargin: 22 }
                text: root.words === 1 ? "1 word" : root.words + " words"
                color: Theme.mute
                opacity: root.words ? 1 : 0
            }

            // история: выкатывается из-под правого края, карточка её подрезает
            Rectangle {
                id: sheet
                width: 360
                y: 110
                height: parent.height - 110 - 18
                x: parent.width - 18 - width + (width + 30) * (1 - root.dt)
                radius: Theme.corner(40)
                color: Theme.s2
                z: 3

                Lb { id: hlab; x: 28; y: 24; text: "notes" }
                Num { anchors.baseline: hlab.baseline; x: hlab.implicitWidth + 42; text: root.view.length; font.pixelSize: 26; color: Theme.grey }

                ListView {
                    id: rows
                    anchors { left: parent.left; right: parent.right; top: hlab.bottom; bottom: parent.bottom; margins: 18 }
                    clip: true
                    spacing: 4
                    model: root.view
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: false
                    section.property: "bucket"
                    section.delegate: Lb {
                        required property string section
                        text: section
                        px: 9
                        x: 20
                        topPadding: 12
                        bottomPadding: 4
                        color: Theme.mute
                    }
                    delegate: Note {}
                    Keys.onPressed: e => {
                        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
                        if (ctrl && e.key === Qt.Key_H) {
                            root.history();
                        } else if (e.key === Qt.Key_Up) {
                            root.sel = Math.max(0, root.sel - 1);
                        } else if (e.key === Qt.Key_Down) {
                            root.sel = Math.max(0, Math.min(root.view.length - 1, root.sel + 1));
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (root.view[root.sel]) root.load(root.view[root.sel]);
                        } else if (e.key === Qt.Key_Delete) {
                            if (root.drawer && !e.isAutoRepeat && root.view[root.sel]) root.burn(root.view[root.sel]);
                        } else if (e.key === Qt.Key_Escape) {
                            root.drawer = false;
                            ed.forceActiveFocus();
                        } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                            input.forceActiveFocus();
                        } else return;
                        e.accepted = true;
                    }
                }

                Lb {
                    visible: root.view.length === 0
                    anchors.centerIn: parent
                    text: root.listedQuery !== root.query ? "searching…" : root.query ? "no matches" : "no notes yet"
                }
            }

            // строка истории: заголовок (первая строка файла) и время; текущая — белая пилюля,
            // выбранная с клавиатуры — подсветка как при наведении
            component Note: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: modelData.name === root.cur
                width: rows.width
                height: 72
                radius: 20
                // base не «transparent»: тот чёрный с нулевой альфой, и анимация к серому на полпути
                // давала тёмную вспышку при наведении (особенно в светлой теме)
                color: row.on ? Theme.fg : (hov.hovered || root.sel === index) ? Theme.s3
                    : Qt.rgba(Theme.s3.r, Theme.s3.g, Theme.s3.b, 0)
                Behavior on color { ColorAnimation { duration: 120 } }

                Column {
                    anchors { left: parent.left; leftMargin: 20; right: tail.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: row.modelData.title
                        font { family: Theme.ui; pixelSize: 16; weight: Font.Medium }
                        color: row.on ? Theme.ink : Theme.fg
                    }
                    Lb { text: root.when(row.modelData.mtime) + (reminders.pending(row.modelData.name) ? " · reminder" : ""); px: 10; color: row.on ? Theme.ink : Theme.grey; opacity: row.on ? 0.6 : 1 }
                }

                Row {
                    id: tail
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        visible: hov.hovered
                        color: copyHover.hovered ? Theme.fg : row.on ? "transparent" : Theme.s1
                        Icon {
                            anchors.centerIn: parent
                            text: "\u{F0C5}"
                            font.pixelSize: 15
                            color: copyHover.hovered ? Theme.ink : row.on ? Theme.ink : Theme.grey
                        }
                        TapHandler { onTapped: root.copyNote(row.modelData) }
                        HoverHandler { id: copyHover; cursorShape: Qt.PointingHandCursor }
                    }
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        visible: hov.hovered
                        color: deleteHover.hovered ? Theme.fg : row.on ? "transparent" : Theme.s1
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font { family: Theme.ui; pixelSize: 20; weight: Font.Medium }
                            color: deleteHover.hovered ? Theme.ink : row.on ? Theme.ink : Theme.grey
                        }
                        TapHandler { onTapped: root.burn(row.modelData) }
                        HoverHandler { id: deleteHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                // открытие — только слева от кнопок: иначе тап по × ещё и «открывал» заметку
                // и закрывал историю, а удалённый файл подставлялся в редактор
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: tail.left }
                    color: "transparent"
                    TapHandler { onTapped: root.load(row.modelData) }
                }

                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
            }

            FocusScope {
                id: reminderMenu
                visible: root.reminderMenuOpen
                anchors { top: pill.bottom; topMargin: 12; right: pill.right }
                width: reminderOptions.implicitWidth + 32
                height: 70
                z: 4

                Keys.onEscapePressed: root.closeReminderMenu()
                Connections {
                    target: root
                    function onReminderPendingChanged() {
                        if (reminderMenu.visible && !root.reminderPending) reminderMinutes.forceActiveFocus();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.corner(24)
                    color: Theme.s2
                    border { width: 1; color: Theme.s3 }
                    MouseArea { anchors.fill: parent }
                }

                Row {
                    id: reminderOptions
                    anchors.centerIn: parent
                    spacing: 12

                    Rectangle {
                        width: 80
                        height: 42
                        radius: Theme.corner(16)
                        color: Theme.s1
                        visible: !root.reminderPending

                        TextInput {
                            id: reminderMinutes
                            anchors { fill: parent; margins: 8 }
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            text: "25"
                            maximumLength: 4
                            color: acceptableInput ? Theme.fg : Theme.accent
                            font { family: Theme.mono; pixelSize: 18 }
                            selectByMouse: true
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 1440; locale: "C" }
                            onActiveFocusChanged: if (activeFocus) selectAll()
                            onAccepted: root.setReminder()
                        }
                    }

                    Lb {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.reminderPending ? reminders.remaining(root.cur) + " left" : "minutes"
                    }
                    Chip {
                        label: root.reminderPending ? "cancel" : "set"
                        enabled: root.reminderPending || reminderMinutes.acceptableInput
                        onTapped: {
                            if (root.reminderPending) {
                                reminders.cancel(root.cur);
                                root.closeReminderMenu();
                            } else root.setReminder();
                        }
                    }
                }
            }

            // средняя кнопка не вставляет primary-выделение: Qt так умеет (QTextControl),
            // но в быстром блокноте это случайная вставка чужого текста.
            // Пустой Item, а не MouseArea: MouseArea навязывает курсор-стрелку над текстом
            Item {
                anchors.fill: parent
                z: 10
                TapHandler { acceptedButtons: Qt.MiddleButton }
            }

        }

        Row {
            anchors { horizontalCenter: card.horizontalCenter; top: card.bottom; topMargin: 24 }
            spacing: 24
            opacity: root.t
            Lb { text: "ctrl+space new" }
            Lb { text: "ctrl+h notes" }
            Lb { text: "ctrl+s save" }
            Lb { text: "esc close" }
            Lb {
                visible: !!text
                text: root.status || (root.transition ? "working…" : "")
                color: root.failed ? Theme.accent : Theme.fg
            }
        }
    }
}
