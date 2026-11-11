import QtQuick
import QtQuick.Layouts
import qs.common
import "TodoLogic.js" as T

// One todo line: checkbox, title, note marker, due label, delete button (on hover).
// Clicking anywhere outside the checkbox / delete button emits opened(); the panel
// then shows the detail view (full title + note, selectable and copyable).
Item {
    id: root
    required property var todo
    property Theme theme: ThemeStore
    property int nowKey: 0
    property int nowMinutes: 0
    signal toggled()
    signal removed()
    signal opened()

    readonly property bool done: !!todo.done
    readonly property bool overdue: T.isOverdue(todo, nowKey, nowMinutes)
    readonly property bool dueToday: !done && T.isDated(todo) && todo.due_key === nowKey
    readonly property string dueText: T.formatDue(todo, nowKey)
    readonly property bool hasContent: !!todo.content && String(todo.content).trim() !== ""

    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusSm
        color: hover.hovered ? theme.surface0 : "transparent"
    }

    HoverHandler { id: hover }

    // Declared before the checkbox / delete MouseAreas, so those sit above it and win.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 8

        Rectangle {
            id: box
            implicitWidth: 18
            implicitHeight: 18
            radius: theme.radiusSm
            // Done is muted grey (like the struck-through title), not an active accent.
            color: root.done ? Qt.alpha(theme.overlay0, 0.2) : "transparent"
            border.width: 1
            border.color: root.done ? theme.overlay0 : theme.overlay1
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                visible: root.done
                text: Glyphs.check
                color: theme.overlay1
                font.pixelSize: theme.fontSizeMin
                font.family: theme.font
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        Text {
            text: root.todo.title
            textFormat: Text.PlainText
            color: root.done ? theme.overlay1 : theme.text
            font.pixelSize: theme.fontSize
            font.family: theme.fontUi
            font.strikeout: root.done
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        // Note marker: this todo has content to show in the detail view.
        Text {
            visible: root.hasContent
            text: Glyphs.note
            color: root.done ? theme.overlay0 : theme.overlay1
            font.pixelSize: theme.fontSizeMin
            font.family: theme.font
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: text !== ""
            text: root.dueText
            color: root.done ? theme.overlay1
                 : root.overdue ? theme.red
                 : root.dueToday ? theme.highlight
                 : theme.subtext0
            font.pixelSize: theme.fontSizeMin
            font.family: theme.fontUi
            Layout.alignment: Qt.AlignVCenter
        }

        IconButton {
            theme: root.theme
            text: Glyphs.close
            glyphSize: theme.fontSizeMin
            opacity: hover.hovered ? 1 : 0
            enabled: hover.hovered
            Layout.alignment: Qt.AlignVCenter
            onClicked: root.removed()
        }
    }
}
