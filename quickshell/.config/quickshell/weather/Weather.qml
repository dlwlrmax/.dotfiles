import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property string _rawText: dataSource ? dataSource.weatherText : ""
    property string weatherText: _rawText && _rawText !== "--" ? _rawText : ""
    property string weatherIcon: {
        var ico = dataSource ? dataSource.weatherIcon : ""
        return ico || "\uF0C2"  //  cloud fallback
    }
    signal togglePanel()

    function refresh() {
        if (dataSource) dataSource.refresh()
    }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        spacing: 2

        Text {
            id: iconText
            text: root.weatherIcon
            color: theme.subtext0
            font.pixelSize: theme.fontSize + 5
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: textText
            text: root.weatherText
            color: theme.subtext0
            font.pixelSize: theme.fontSize
            font.weight: Font.Medium
            font.family: theme.font
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
