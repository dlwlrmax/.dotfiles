import QtQuick
import QtQuick.Layouts

// Standard panel title row: title, optional extra items (badges, actions), close.
RowLayout {
    id: header

    property Theme theme: ThemeStore
    property string title: ""
    default property alias extra: extraRow.data
    signal close()

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: header.title
        color: header.theme.text
        font.pixelSize: header.theme.fontSize + 1
        font.bold: true
        font.family: header.theme.font
    }

    Item { Layout.fillWidth: true }

    RowLayout {
        id: extraRow
        spacing: 8
    }

    IconButton {
        theme: header.theme
        text: Glyphs.close
        onClicked: header.close()
    }
}
