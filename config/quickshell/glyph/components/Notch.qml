import QtQuick

// колесо по засечкам: notch(±1) на каждые 120 угла. Высокоточное колесо шлёт по 15 за щелчок — копим, иначе 8 шагов за засечку.
// MouseArea, не WheelHandler: тот на пилюле бара колесо не получал (сверяет точку ещё и с геометрией окна), MouseArea получает.
// Тачпад не берём (scrollGestureEnabled) — свайп не листает; кнопки и наведение проходят насквозь
MouseArea {
    signal notch(int d) // +1 — колесо от себя
    property real acc: 0
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: false
    onWheel: e => {
        acc += e.angleDelta.y || e.angleDelta.x;
        while (Math.abs(acc) >= 120) {
            notch(Math.sign(acc));
            acc -= Math.sign(acc) * 120;
        }
    }
}
