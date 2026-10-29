import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common

// Wallpaper browser: thumbnails of the wallpaper folder; click one to set it.
// With the wallpaper theme on, the shell palette follows the choice.
Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var wp: null              // DataProviders.wallpaperData
    signal close()

    property string query: ""
    readonly property var items: {
        var all = wp ? wp.items : []
        var q = query.trim().toLowerCase()
        return q === "" ? all : all.filter(function (w) { return w.name.toLowerCase().indexOf(q) >= 0 })
    }
    readonly property int columns: 4
    readonly property real cellW: Math.floor(grid.width / columns) - 10

    implicitWidth: 820
    implicitHeight: 620
    focus: true

    onActiveChanged: {
        if (!active) return
        query = ""
        search.text = ""
        if (wp) { wp.refreshCurrent(); wp.loadList() }
        Qt.callLater(function () { search.forceActiveFocus() })
        Qt.callLater(root.scrollToCurrent)
    }

    function scrollToCurrent() {
        if (!wp) return
        for (var i = 0; i < items.length; i++)
            if (items[i].path === wp.current) { grid.positionViewAtIndex(i, GridView.Center); return }
    }

    onItemsChanged: if (active) Qt.callLater(root.scrollToCurrent)

    // Centered overlay: rounded on all sides, opaque.
    Rectangle {
        anchors.fill: parent
        radius: theme.panelRadius
        color: theme.panelColorSolid
        border.color: theme.surface1
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.panelMargin
        spacing: 10

        PanelHeader {
            theme: root.theme
            title: "Wallpapers"
            onClose: root.close()

            Badge {
                visible: !!root.wp && root.wp.thumbsBusy
                theme: root.theme
                text: "making thumbnails…"
                clr: theme.yellow
            }

            Badge {
                theme: root.theme
                text: Glyphs.refresh + " Random"
                clr: theme.blue
                clickable: true
                onClicked: if (root.wp) root.wp.random()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: theme.radiusMd
                color: theme.mantle
                border.width: search.activeFocus ? 1 : 0
                border.color: theme.highlight

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.margins: 8
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.family: theme.fontUi
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    onTextEdited: root.query = text
                    Keys.onEscapePressed: root.close()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text.length
                        text: "Filter " + (root.wp ? root.wp.items.length : 0) + " wallpapers"
                        color: theme.overlay0
                        font.pixelSize: theme.fontSize
                        font.family: theme.fontUi
                    }
                }
            }

            Text {
                text: root.items.length + (root.query ? " shown" : " total")
                color: theme.overlay0
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.items
            cellWidth: Math.floor(grid.width / root.columns)
            cellHeight: root.cellW * 9 / 16 + 10
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isCurrent: !!root.wp && root.wp.current === modelData.path
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: card
                    width: root.cellW
                    height: root.cellW * 9 / 16
                    radius: theme.radiusLg
                    color: theme.surface0
                    clip: true
                    border.width: cell.isCurrent ? 3 : (ma.containsMouse ? 2 : 0)
                    border.color: cell.isCurrent ? theme.highlight : theme.overlay1
                    scale: ma.containsMouse ? 1.02 : 1
                    Behavior on scale { SpringAnimation { spring: theme.springPress; damping: theme.dampingPress; epsilon: theme.epsilonPress } }

                    Image {
                        id: img
                        anchors.fill: parent
                        anchors.margins: card.border.width
                        source: "file://" + cell.modelData.thumb
                        sourceSize.width: 480
                        sourceSize.height: 270
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true

                        // reload once the thumbnail exists (they are made in the background)
                        property int ver: root.wp ? root.wp.thumbVersion : 0
                        onVerChanged: { var s = source; source = ""; source = s }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: img.status !== Image.Ready
                        text: img.status === Image.Error ? "" : "…"
                        color: theme.overlay0
                        font.pixelSize: theme.fontSize + 10
                        font.family: theme.font
                    }

                    // name strip on hover / current
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 24
                        visible: ma.containsMouse || cell.isCurrent
                        color: Qt.alpha(theme.crust, 0.78)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            text: (cell.isCurrent ? "  " : "") + cell.modelData.name
                            color: cell.isCurrent ? theme.highlight : theme.text
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.fontUi
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.wp) root.wp.set(cell.modelData.path)
                    }
                }
            }
        }

        // current palette preview
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: Prefs.themeMode === "wallpaper" ? (root.wp && root.wp.generating ? "Generating palette…" : "Palette") : "Theme: Catppuccin (switch in Settings)"
                color: theme.subtext0
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
                Layout.rightMargin: 6
            }

            Repeater {
                model: ["base", "surface1", "overlay1", "text", "red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink", "highlight"]

                Rectangle {
                    required property string modelData
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 14
                    radius: 4
                    color: modelData === "highlight" ? theme.highlight : theme[modelData]
                    border.width: 1
                    border.color: Qt.alpha(theme.text, 0.2)
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.wp ? root.wp.folder : ""
                color: theme.overlay0
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
                elide: Text.ElideMiddle
                Layout.maximumWidth: 300
            }
        }
    }
}
