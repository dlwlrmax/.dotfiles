import QtQuick
import QtQuick.Layouts
import qs.common

// Bar button that opens the quick-controls panel.
Item {
    id: root
    property Theme theme: ThemeStore
    signal togglePanel()
    // Problems reported by HealthData: shown as a dot on the icon.
    property int issueCount: 0
    property bool hasErrors: false

    implicitWidth: icon.implicitWidth + 6
    implicitHeight: icon.implicitHeight + 4
    Layout.alignment: Qt.AlignVCenter

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\udb81\udc93"   // nf-md-cog
        color: ma.containsMouse ? root.theme.text : root.theme.subtext1
        font.pixelSize: root.theme.fontSize + 8
        font.family: root.theme.font
    }

    Rectangle {
        visible: root.issueCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.rightMargin: 0
        width: 8
        height: 8
        radius: 4
        color: root.hasErrors ? root.theme.red : root.theme.yellow
        border.width: 1
        border.color: root.theme.capsuleColor
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: ma.containsMouse
        text: root.issueCount > 0 ? "Settings \u00b7 " + root.issueCount + " issue" + (root.issueCount === 1 ? "" : "s")
                                  : "Settings"
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePanel()
    }
}
