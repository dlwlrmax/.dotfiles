import QtQuick
import QtQuick.Layouts

// Rounded panel section with a small title; children stack vertically.
Rectangle {
    id: card

    property Theme theme
    property string title: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 20
    radius: theme.radiusLg
    color: Qt.alpha(theme.surface0, 0.45)

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Text {
            visible: card.title !== ""
            text: card.title
            color: card.theme.subtext1
            font.pixelSize: card.theme.fontSize - 1
            font.bold: true
            font.family: card.theme.font
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
        }
    }
}
