import QtQuick

// Turns wheel deltas into whole notches (120 units each). Accumulates, so
// hi-res wheels and touchpads step evenly instead of firing per tiny event.
//   WheelSteps { id: steps }  …  onWheel: w => { var n = steps.feed(w.angleDelta.y); if (n) … }
QtObject {
    property real _acc: 0

    // Returns the number of whole notches crossed (negative = down), usually 0 or ±1.
    function feed(deltaY) {
        _acc += deltaY
        if (Math.abs(_acc) < 120) return 0
        var n = Math.trunc(_acc / 120)
        _acc -= n * 120
        return n
    }
}
