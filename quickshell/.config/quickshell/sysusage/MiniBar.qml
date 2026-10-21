import QtQuick
import QtQuick.Layouts
import qs.common

// One-line "LABEL ▮▮▮▯▯ detail pct" gauge (swap while calm, disk).
RowLayout {
    id: bar

    property Theme theme
    property string label: ""
    property int pct: 0
    property string detail: ""
    property color barClr: "transparent"

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: bar.label
        color: bar.theme.subtext1
        font.pixelSize: bar.theme.fontSizeMin
        font.bold: true
        font.family: bar.theme.font
        Layout.preferredWidth: 36
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        radius: 3
        color: Qt.alpha(bar.theme.surface0, 0.8)

        Rectangle {
            width: parent.width * Math.min(bar.pct, 100) / 100
            height: parent.height
            radius: parent.radius
            color: bar.barClr
        }
    }

    Text {
        text: bar.detail
        color: bar.theme.subtext0
        font.pixelSize: bar.theme.fontSizeMin
        font.family: bar.theme.font
    }

    Text {
        text: bar.pct + "%"
        color: bar.barClr
        font.pixelSize: bar.theme.fontSizeMin
        font.bold: true
        font.family: bar.theme.font
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 30
    }
}
