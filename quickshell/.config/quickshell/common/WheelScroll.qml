import QtQuick

// Fast wheel for panel Flickables: one notch jumps Prefs.wheelStep pixels
// instead of the platform default, for hi-res mice that scroll too slowly.
// wheelStep 0 (the default on other machines) disables the handler entirely,
// so scrolling stays native. Declare inside the target:
//   Flickable { id: scroll …  WheelScroll { flick: scroll } }
// Inner wheel widgets (sliders, nested lists) are deeper, so they still get
// the event first and are unaffected.
WheelHandler {
    // The Flickable this handler scrolls.
    property Flickable flick: parent

    // Handlers take no QML children; the accumulator lives as a property.
    property WheelSteps steps: WheelSteps {}

    // No auto-manipulation; onWheel drives contentY itself.
    target: null
    // A live WheelHandler takes the parent's wheel events even when onWheel
    // does not accept, killing native scrolling — so native mode (wheelStep 0)
    // must disable the handler outright, not just decline the event.
    enabled: Prefs.wheelStep > 0
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: (event) => {
        var n = steps.feed(event.angleDelta.y)
        if (!n || Prefs.wheelStep <= 0) return
        event.accepted = true
        flick.cancelFlick()
        var y = flick.contentY - n * Prefs.wheelStep
        flick.contentY = Math.max(flick.originY, Math.min(y, flick.originY + Math.max(0, flick.contentHeight - flick.height)))
    }
}
