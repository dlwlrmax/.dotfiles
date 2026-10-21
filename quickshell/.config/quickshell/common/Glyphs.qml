pragma Singleton
import QtQuick

// Nerd Font glyphs shared by panels, so icons stay one visual family.
QtObject {
    readonly property string close: "\uf00d"
    readonly property string prev: "\uf053"
    readonly property string next: "\uf054"
    readonly property string down: "\uf078"
    readonly property string up: "\uf077"
    readonly property string check: "\uf00c"
    readonly property string copy: "\uf0c5"
    readonly property string refresh: "\uf021"
    readonly property string trash: "\uf1f8"
    readonly property string download: "\uf175"
    readonly property string upload: "\uf176"
    readonly property string reply: "\uf112"
}
