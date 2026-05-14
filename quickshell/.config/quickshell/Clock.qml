import QtQuick
import QtQuick.Layouts

Text {
    property Theme theme: Theme {}
    id: clock
    color: theme.text
    font.pixelSize: theme.fontSize
    font.family: theme.font
    font.bold: true
    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.text = new Date().toLocaleString(Qt.locale(), "hh:mm dd/MM");
    }
}
