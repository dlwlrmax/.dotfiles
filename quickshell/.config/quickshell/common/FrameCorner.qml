import QtQuick
import QtQuick.Shapes

// Concave fillet that joins the bar/panel frame to whatever it meets. Fills the
// part of a radius x radius square that lies outside a circle centred on the
// opposite corner: the filled corner is top-left, or top-right when `flipX`.
Shape {
    id: root

    property Theme theme: ThemeStore
    property color color: theme.barColor
    property bool flipX: false
    property int radius: theme.frameRadius

    width: radius
    height: radius
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
        origin.x: root.width / 2
        xScale: root.flipX ? -1 : 1
    }

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: -1
        startX: 0
        startY: 0
        PathLine { x: root.radius; y: 0 }
        PathArc {
            x: 0
            y: root.radius
            radiusX: root.radius
            radiusY: root.radius
            direction: PathArc.Counterclockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
