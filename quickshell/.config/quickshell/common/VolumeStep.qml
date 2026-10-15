pragma Singleton
import QtQuick

QtObject {
    // Volume after `steps` 5% notches from `cur` (0..1+), snapped to the 5% grid.
    // Capped at 100%, or at `cur` if it's already above that (set elsewhere), so
    // scrolling up never pulls a boosted level down.
    function target(cur, steps) {
        return Math.max(0, Math.min(Math.max(1, cur), Math.round(cur * 20 + steps) / 20))
    }
}
