import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null      // DataProviders.todoData
    signal close()

    readonly property var items: dataSource ? dataSource.items : []
    readonly property int doneCount: items.length - (dataSource ? dataSource.pendingCount : 0)

    // Capped to the screen under the bar; the list scrolls beyond that.
    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(880, scr ? scr.height - theme.barHeight - 24 : 880)
    }

    focus: true
    Keys.onEscapePressed: root.close()

    clip: true
    implicitWidth: theme.panelWidthM
    implicitHeight: Math.min(maxHeight, Math.max(220, content.implicitHeight + 2 * theme.panelMargin))

    onActiveChanged: if (active) {
        list.positionViewAtBeginning()
        Qt.callLater(function () { addBar.focusTitle() })
    }

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: theme.panelMargin
        spacing: 10

        PanelHeader {
            theme: root.theme
            title: "Todo"
            onClose: root.close()

            Badge {
                theme: root.theme
                text: root.dataSource ? root.dataSource.pendingCount : 0
                clr: root.dataSource && root.dataSource.overdueCount > 0 ? theme.red : theme.subtext0
            }

            IconButton {
                theme: root.theme
                text: Glyphs.trash
                enabled: root.doneCount > 0
                onClicked: if (root.dataSource) root.dataSource.clearDone()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            implicitHeight: list.contentHeight

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.items

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: TodoRow {
                    required property var modelData
                    width: ListView.view.width
                    todo: modelData
                    theme: root.theme
                    nowKey: root.dataSource ? root.dataSource.nowKey : 0
                    nowMinutes: root.dataSource ? root.dataSource.nowMinutes : 0
                    onToggled: root.dataSource.toggle(modelData.id)
                    onRemoved: root.dataSource.remove(modelData.id)
                }
            }

            // Sibling of the ListView (not a child: a Flickable reparents children into
            // its contentItem, which is 0 high when empty).
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Nothing to do"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.fontUi
            }
        }

        TodoAddBar {
            id: addBar
            Layout.fillWidth: true
            theme: root.theme
            todayKey: root.dataSource ? root.dataSource.nowKey : 0
            onSubmitted: (title, dueKey, dueMinutes) => {
                if (root.dataSource) root.dataSource.add(title, dueKey, dueMinutes)
            }
        }
    }
}
