import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import qs
import qs.components

// список под пилюлями (правый клик по Wi-Fi/Bluetooth). Сети: клик подключает и отключает, новая защищённая — строка пароля.
// Устройства: связанные клик соединяет и разрывает, чужие — знакомит (pair). Ищет, только пока список открыт
Rectangle {
    id: root
    property string kind // "wifi" | "bt" | "" — закрыт
    signal touched       // любой клик внутри — панель приколота

    readonly property bool open: kind === "wifi" || kind === "bt"
    // что показано: закрыли — остаётся, пока список сжимается (Quick), иначе он пустел бы сразу
    property string shown
    onVisibleChanged: if (!visible) shown = ""
    readonly property bool isWifi: shown === "wifi"
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool on: isWifi ? Networking.wifiEnabled : bt?.enabled ?? false
    // сеть со страницей входа: сам портал (и снятие vpn) открывает Vpn, здесь — открыть его снова, если вкладку закрыли
    readonly property bool portal: Networking.connectivity === NetworkConnectivity.Portal

    property var ask: null // сеть, которой нужен пароль
    // доверие — когда знакомство состоялось, не до: доверенному BlueZ пускает входящие подключения без спроса, и отменённое
    // знакомство с чужим «наушником» оставляло бы его доверенным. Доверенный сам переподключается (наушники из кейса)
    property var pend: null
    property var pairNext: null
    Connections {
        target: root.pend
        function onPairedChanged() { root.settle() }
        function onPairingChanged() { root.settle() }
    }
    // знакомство закончилось: доверяем только после успеха. Connect во время Pair BlueZ отвергает, а сразу после —
    // наушники часто подключаются сами, и второй connect поверх этого даёт connect → disconnect. Ждём, проверяем, потом подключаем
    function settle() {
        const d = root.pend;
        if (!d) return;
        if (!(d.paired || d.bonded)) {
            if (!d.pairing) root.pend = null;
            return;
        }
        if (d.pairing) return;
        root.pend = null;
        d.trusted = true;
        root.pairNext = d;
        pairConnect.restart();
    }
    Timer {
        id: pairConnect
        interval: 600
        onTriggered: {
            const d = root.pairNext;
            root.pairNext = null;
            if (!d || d.connected || d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting) return;
            d.connect();
        }
    }
    property string err
    // kind, не open: привязка open к этому сигналу может быть ещё не пересчитана, и первое открытие показывало bluetooth
    onKindChanged: { if (kind === "wifi" || kind === "bt") shown = kind; ask = null; err = ""; fl.contentY = 0; }
    // пароль ушёл — фокус обратно на панель, чтобы Esc закрывал её; список — к началу, строка пароля на виду
    onAskChanged: { fl.contentY = 0; if (!ask && pw.activeFocus) root.forceActiveFocus(); }

    Binding { when: root.kind === "wifi" && root.on; target: root.wifi; property: "scannerEnabled"; value: true }
    Binding { when: root.kind === "bt" && root.on; target: root.bt; property: "discovering"; value: true }

    // своя сверху, дальше сохранённые, дальше по силе. Пока вводят пароль — только та сеть: пересортировка не съест набранное
    readonly property var nets: !isWifi || !wifi ? [] : wifi.networks.values.filter(n => n.name)
        .sort((a, b) => b.connected - a.connected || b.known - a.known || b.signalStrength - a.signalStrength).slice(0, 6)
    // безымянные (только адрес) — шум эфира
    readonly property var devs: shown !== "bt" || !bt ? [] : bt.devices.values.filter(d => d.paired || d.bonded || d.connected || d.deviceName)
    // знакомые всегда сверху и отдельной группой: paired/bonded не даёт им смешаться с чужими устройствами вокруг
    readonly property var known: devs.filter(d => d.paired || d.bonded || d.connected)
        .sort((a, b) => b.connected - a.connected || b.paired - a.paired)
    readonly property var nearby: devs.filter(d => !(d.paired || d.bonded || d.connected))
        .sort((a, b) => (a.name || a.address).localeCompare(b.name || b.address)).slice(0, 6)
    readonly property var rows: !on ? [] : ask ? [ask] : isWifi ? nets : devs

    function bars(n) {
        const lock = n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
        const i = Math.min(3, Math.floor(n.signalStrength * 4));
        return (lock ? ["\u{F0920}", "\u{F0923}", "\u{F0926}", "\u{F0929}"] : ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"])[i];
    }
    function btIcon(i) {
        return /audio|head/.test(i) ? "\u{F02CB}" : /mouse/.test(i) ? "\u{F037D}" : /keyboard/.test(i) ? "\u{F030C}" : /phone/.test(i) ? "\u{F03F2}" : "\u{F00AF}";
    }
    // ponytail: enterprise (EAP) сюда не пролезет — только psk; понадобится — nmcli в demonshot Settings
    function tap(o) {
        touched();
        err = "";
        if (!isWifi) {
            if (o.pairing) return o.cancelPair();
            if (o.connected) return o.disconnect();
            if (o.state === BluetoothDeviceState.Connecting || o.state === BluetoothDeviceState.Disconnecting) return;
            // уже знакомы — только connect; pair() на связанном устройстве BlueZ отвергает, а «pair + сразу connect» рвёт связь
            if (o.paired || o.bonded) return o.connect();
            pend = o;
            return o.pair();
        }
        if (o.connected) return portal ? Qt.openUrlExternally("http://neverssl.com") : o.disconnect();
        if (o.known || o.security === WifiSecurityType.Open || o.security === WifiSecurityType.Owe) return o.connect();
        ask = o;
    }

    // потолок задаёт Quick: выше — список листается, а не выталкивает панель за экран
    property real max: Infinity
    height: Math.min(list.height + 32, max)
    radius: Theme.corner(30)
    color: Theme.s2

    Flickable {
        id: fl
        x: 16
        y: 16
        width: parent.width - 32
        height: parent.height - 32
        contentHeight: list.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: fl.width
            spacing: 4

            Item {
                width: parent.width
                height: 24
                Lb {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: !root.on ? `${root.isWifi ? "wi-fi" : "bluetooth"} · off`
                        : root.ask ? "password"
                        : root.isWifi ? `networks · ${root.nets.length}` : `devices · ${root.bt?.discovering ? "searching" : root.known.length + root.nearby.length}`
                }
                Lb {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    rightPadding: 4
                    width: Math.min(implicitWidth, parent.width * 0.6)
                    elide: Text.ElideRight
                    visible: !!root.err || !!root.ask
                    text: root.err || "cancel"
                    color: Theme.fg
                    TapHandler { onTapped: { root.touched(); root.err = ""; root.ask = null; } }
                }
            }

            // одна строка на сеть и на устройство
            Component {
                id: deviceRow
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var o: modelData
                    readonly property bool on: o.connected
                    readonly property bool busy: root.isWifi ? o.stateChanging : o.pairing || o.state === BluetoothDeviceState.Connecting || o.state === BluetoothDeviceState.Disconnecting
                    width: list.width
                    height: 56
                    radius: Theme.corner(28)
                    color: hov.hovered ? Theme.s3 : "transparent"

                    Rectangle {
                        id: ic
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: row.on ? Theme.fg : Theme.s3
                        Icon {
                            anchors.centerIn: parent
                            text: root.isWifi ? root.bars(row.o) : root.btIcon(row.o.icon)
                            font.pixelSize: 19
                            color: row.on ? Theme.ink : Theme.fg
                            // идёт соединение — иконка дышит
                            SequentialAnimation on opacity {
                                running: row.busy
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) parent.opacity = 1
                                NumberAnimation { to: 0.25; duration: 450 }
                                NumberAnimation { to: 1; duration: 450 }
                            }
                        }
                    }
                    Column {
                        anchors { left: ic.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: row.o.name || row.o.address; font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold } color: Theme.fg }
                        Lb {
                            px: 10
                            text: root.isWifi
                                ? `${row.on ? (root.portal ? "sign in" : "connected") : row.busy ? "connecting" : row.o.known ? "saved" : WifiSecurityType.toString(row.o.security).toLowerCase()} · ${Math.round(row.o.signalStrength * 100)}%`
                                : (row.o.pairing ? "pairing" : row.o.state === BluetoothDeviceState.Connecting ? "connecting" : row.o.state === BluetoothDeviceState.Disconnecting ? "disconnecting"
                                   : row.on ? "connected" : (row.o.paired || row.o.bonded) ? "paired" : "pair") + (row.o.batteryAvailable ? ` · ${Math.round(row.o.battery * 100)}%` : "")
                        }
                    }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.tap(row.o) }
                    // правый клик по сохранённой — забыть
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.touched(); if (row.o.known || row.o.paired || row.o.bonded) row.o.forget(); } }
                    // нет пароля или он не тот — NM просит секрет: снова строка пароля
                    Connections {
                        target: root.isWifi ? row.o : null
                        ignoreUnknownSignals: true
                        function onConnectionFailed(r) {
                            if (r === ConnectionFailReason.NoSecrets) root.ask = row.o;
                            else root.err = ConnectionFailReason.toString(r);
                        }
                    }
                }
            }

            Repeater {
                model: root.isWifi ? root.rows : []
                delegate: deviceRow
            }

            // связанные — отдельной группой сверху, чтобы не мешались с чужими устройствами вокруг
            Lb {
                visible: root.shown === "bt" && root.on && root.known.length > 0
                x: 4
                px: 10
                topPadding: 8
                bottomPadding: 2
                text: `paired · ${root.known.length}`
            }
            Repeater {
                model: root.shown === "bt" && root.on ? root.known : []
                delegate: deviceRow
            }

            Lb {
                visible: root.shown === "bt" && root.on && root.nearby.length > 0
                x: 4
                px: 10
                topPadding: 8
                bottomPadding: 2
                text: `nearby · ${root.nearby.length}`
            }
            Repeater {
                model: root.shown === "bt" && root.on ? root.nearby : []
                delegate: deviceRow
            }

            Rectangle {
                visible: !!root.ask
                width: list.width
                height: 56
                radius: Theme.corner(28)
                color: Theme.s1
                border { width: 1; color: Theme.s3 }
                onVisibleChanged: if (visible) pw.forceActiveFocus()
                TextInput {
                    id: pw
                    anchors { left: parent.left; leftMargin: 22; right: go.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font { family: Theme.mono; pixelSize: 16; letterSpacing: 2 }
                    color: Theme.fg
                    selectionColor: Theme.fg
                    selectedTextColor: Theme.ink
                    clip: true
                    onAccepted: if (text) go.send()
                    Lb { visible: !pw.text; anchors.verticalCenter: parent.verticalCenter; text: "enter password"; color: Theme.mute }
                }
                Rectangle {
                    id: go
                    function send() { root.touched(); root.ask.connectWithPsk(pw.text); pw.text = ""; root.ask = null; }
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 44
                    height: 44
                    radius: 22
                    color: pw.text ? Theme.fg : Theme.s3
                    Icon { anchors.centerIn: parent; text: "\u{F0054}"; font.pixelSize: 19; color: pw.text ? Theme.ink : Theme.grey }
                    TapHandler { onTapped: if (pw.text) go.send() }
                }
            }

            Lb {
                visible: root.on && !root.ask && !root.rows.length
                x: 4
                topPadding: 4
                bottomPadding: 4
                text: root.isWifi ? "scanning…" : "nothing nearby"
            }
        }
    }
}
