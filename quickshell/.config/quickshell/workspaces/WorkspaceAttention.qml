pragma Singleton
// Unseen new windows, shared by every monitor's Workspaces bar (one event
// listener, and a mark survives its workspace moving to another monitor).
//   marks: workspace name -> { address: true }
// A mark lives only while a window that caused it is still open, so a splash
// screen or popup that came and went leaves nothing behind. Workspaces.qml
// clears a workspace's mark when it becomes visible.
import QtQuick
import Quickshell
import Quickshell.Hyprland._Ipc

Singleton {
    id: root
    property var marks: ({})

    function has(ws) { return marks[ws] !== undefined }

    function _update(fn) {
        var next = {}
        for (var k in marks) next[k] = Object.assign({}, marks[k])
        fn(next)
        for (var n in next) if (Object.keys(next[n]).length === 0) delete next[n]
        marks = next   // reassign so bindings update
    }
    function markOpen(ws, addr) { _update(function(m) { (m[ws] = m[ws] || {})[addr] = true }) }
    function forgetWindow(addr) {
        for (var k in marks) {
            if (marks[k][addr]) {
                _update(function(m) { for (var j in m) delete m[j][addr] })
                return
            }
        }
    }
    function clear(ws) { if (marks[ws]) _update(function(m) { delete m[ws] }) }

    function isVisible(name) {
        var list = Hyprland.workspaces.values
        for (var i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i].active || list[i].focused
        return false   // not created yet: a silent open never makes it visible
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow": {           // ADDRESS,WORKSPACENAME,CLASS,TITLE
                var p = event.parse(4)
                if (p[1] && !root.isVisible(p[1])) root.markOpen(p[1], p[0])
                break
            }
            case "closewindow":            // ADDRESS
                root.forgetWindow(event.data)
                break
            case "movewindowv2":           // ADDRESS,WORKSPACEID,WORKSPACENAME — you moved it
                root.forgetWindow(event.parse(3)[0])
                break
            case "destroyworkspace":       // WORKSPACENAME
                root.clear(event.data)
                break
            }
        }
    }
}
