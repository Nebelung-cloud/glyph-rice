import QtQuick

// колесо по засечкам: notch(±1) на каждые 120 угла. Высокоточное колесо шлёт по 15 за щелчок — копим, иначе 8 шагов за засечку.
// Тачпад WheelHandler по умолчанию не берёт (acceptedDevices: Mouse) — свайп не листает
WheelHandler {
    signal notch(int d) // +1 — колесо от себя
    property real acc: 0
    onWheel: e => {
        acc += e.angleDelta.y || e.angleDelta.x;
        while (Math.abs(acc) >= 120) {
            notch(Math.sign(acc));
            acc -= Math.sign(acc) * 120;
        }
    }
}
