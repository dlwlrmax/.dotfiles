import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var screen
    required property bool active
    signal closeRequested()

    enum Position { TopRight, TopCenter, Center }
    property int position: PanelOverlay.Position.TopRight
    property int rightMargin: 30
    property int centerOffset: 0
    property int topMargin: 0
    property bool keyboardFocus: true

    default property alias content: wrapper.data

    screen: root.screen
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    color: "transparent"
    visible: root.active || wrapper.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.keyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            var pos = mapToItem(wrapper, mouse.x, mouse.y)
            if (pos.x < 0 || pos.x > wrapper.width || pos.y < 0 || pos.y > wrapper.height) {
                root.closeRequested()
            }
        }
    }

    Item {
        id: wrapper
        anchors.top: parent.top
        opacity: 0
        focus: true
        clip: true
        Keys.onEscapePressed: root.closeRequested()

        // Never collapse to 0x0: content that has not reported an implicit size
        // yet would otherwise be clipped away entirely.
        width: children.length > 0 ? Math.max(children[0].implicitWidth, 1) : 1
        height: children.length > 0 ? Math.max(children[0].implicitHeight, 1) : 1

        Binding {
            target: wrapper.anchors
            property: "topMargin"
            value: root.topMargin
        }

        Binding {
            target: wrapper.anchors
            property: "rightMargin"
            value: root.rightMargin
            when: root.position === PanelOverlay.Position.TopRight
        }

        Binding {
            target: wrapper.anchors
            property: "horizontalCenterOffset"
            value: root.centerOffset
            when: root.position === PanelOverlay.Position.TopCenter
        }

        Component.onCompleted: {
            switch (root.position) {
                case PanelOverlay.Position.TopRight:
                    wrapper.anchors.right = parent.right
                    break
                case PanelOverlay.Position.TopCenter:
                    wrapper.anchors.horizontalCenter = parent.horizontalCenter
                    break
                case PanelOverlay.Position.Center:
                    wrapper.anchors.centerIn = parent
                    break
            }
        }

        transform: Translate { id: panelTranslate; y: -20 }

        states: State {
            name: "open"
            when: root.active
            PropertyChanges { target: wrapper; opacity: 1 }
            PropertyChanges { target: panelTranslate; y: 0 }
        }

        transitions: Transition {
            from: ""; to: "open"
            reversible: true
            ParallelAnimation {
                NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: panelTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
}
