import QtQuick
import qs.common

// Notification avatar. For notifications relayed by KDE Connect it stacks the
// phone app's own icon (front) over the KDE Connect icon (behind, offset), like
// an avatar stack; otherwise it is the usual single app icon or a mail glyph.
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

    implicitWidth: stacked ? Math.round(size * 1.55) : size
    implicitHeight: size

    // KDE Connect (source) — behind and to the right.
    Rectangle {
        visible: root.stacked
        width: root.size * 0.8
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.surface0
        border.width: 1
        border.color: root.theme.surface1

        AppIcon {
            anchors.centerIn: parent
            appId: root.notif && root.notif.desktopEntry || ""
            iconName: root.notif && root.notif.appIcon || ""
            size: parent.width * 0.68
            hideOnMissing: true
        }
    }

    // Phone app (or the plain app icon) — in front, left.
    Rectangle {
        width: root.size
        height: root.size
        radius: root.size / 2
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.surface1
        border.width: root.stacked ? 2 : 0
        border.color: root.theme.panelColorSolid

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
