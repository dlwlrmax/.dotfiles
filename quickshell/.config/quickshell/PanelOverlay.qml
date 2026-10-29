import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.common

PanelWindow {
    id: root

    required property bool active
    signal closeRequested()

    enum Position { TopRight, TopCenter, Center }
    property int position: PanelOverlay.Position.TopRight
    property int rightMargin: 30
    property int centerOffset: 0
    property int topMargin: 0
    property bool keyboardFocus: true

    default property alias content: wrapper.data
    // Item that gets key events first (set by PanelHost to the loaded panel).
    property Item keyTarget: null

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
        // Content gets first look at keys (e.g. calendar arrows); Escape stays here.
        Keys.forwardTo: root.keyTarget ? [root.keyTarget] : (children.length > 0 ? [children[0]] : [])
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

        // TopCenter: centred on `centerOffset` from the screen centre (a bar widget),
        // kept fully on-screen.
        Binding {
            target: wrapper
            property: "x"
            value: Math.max(8, Math.min(root.width - wrapper.width - 8,
                                        root.width / 2 + root.centerOffset - wrapper.width / 2))
            when: root.position === PanelOverlay.Position.TopCenter
        }

        Component.onCompleted: {
            switch (root.position) {
                case PanelOverlay.Position.TopRight:
                    wrapper.anchors.right = parent.right
                    break
                case PanelOverlay.Position.TopCenter:
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
                SpringAnimation { target: panelTranslate; property: "y"; spring: ThemeStore.springMove; damping: ThemeStore.dampingMove; epsilon: ThemeStore.epsilonMove }
            }
        }
    }
}
