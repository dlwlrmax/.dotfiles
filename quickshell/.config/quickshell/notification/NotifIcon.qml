import QtQuick
import qs.common

// Notification avatar. For notifications relayed by KDE Connect it stacks the
// phone app's own icon (front, lower right) over the KDE Connect icon (behind,
// upper left) as two overlapping circles; otherwise it is the usual single app icon or a mail glyph.
Item {
    id: root

    property Theme theme: ThemeStore
    property var notif: ({})
    property int size: 36

    readonly property bool isPhone: !!notif && (notif.appName || "") === "KDE Connect"
    // KDE Connect puts the phone app's name in the summary.
    readonly property string phoneIcon: isPhone
        ? (ShellState.phoneAppIcons[(notif.summary || "").trim().toLowerCase()] || "") : ""
    readonly property bool stacked: phoneImg.status === Image.Ready

    readonly property real dx: Math.round(size * 0.25)
    readonly property real dy: Math.round(size * 0.3)

    // Same width stacked or not, so text lines up across notifications.
    implicitWidth: size + dx
    implicitHeight: stacked ? size + dy : size

    // KDE Connect (source) — behind, upper left.
    Rectangle {
        visible: root.stacked
        width: root.size * 0.9
        height: width
        radius: width / 2
        anchors.left: parent.left
        anchors.top: parent.top
        color: root.theme.surface0

        AppIcon {
            anchors.centerIn: parent
            appId: root.notif && root.notif.desktopEntry || ""
            iconName: root.notif && root.notif.appIcon || ""
            size: parent.width * 0.68
            hideOnMissing: true
        }
    }

    // Phone app (or the plain app icon) — in front, lower right.
    Rectangle {
        width: root.size
        height: root.size
        radius: root.size / 2
        // Lower right when stacked; centered in the fixed width otherwise.
        x: root.stacked ? root.dx : root.dx / 2
        y: root.stacked ? root.dy : 0
        color: root.theme.surface1

        Image {
            id: phoneImg
            anchors.centerIn: parent
            width: root.size * 0.68
            height: width
            source: root.phoneIcon ? "file://" + root.phoneIcon : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            // The phone ships ~91px icons; let Qt downscale them once, filtered,
            // instead of sampling the big texture at 24px.
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            smooth: true
            mipmap: true
            visible: status === Image.Ready
        }

        AppIcon {
            id: appIcon
            anchors.centerIn: parent
            appId: root.notif && root.notif.desktopEntry || ""
            iconName: root.notif && root.notif.appIcon || ""
            size: root.size * 0.67
            hideOnMissing: true
            visible: !root.stacked
        }

        Text {
            anchors.centerIn: parent
            text: ""
            color: root.theme.subtext0
            font.pixelSize: root.theme.iconSize
            font.family: root.theme.font
            visible: !root.stacked && !appIcon.iconFound
        }
    }
}
