import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    id: card

    property Theme theme
    property string label: ""
    property var history: []
    property int pct: 0
    property int minVal: 0
    property int maxVal: 0
    property string subText: ""
    property string subColor: ""
    property bool subVisible: true
    property string lineClr: ""
    property string fillClr: ""
    property bool hasData: false

    Layout.fillWidth: true
    Layout.fillHeight: true

    function requestPaint() {
        spark.requestPaint()
    }

    // Sparkline is drawn imperatively so no binding churn on every sample.
    function drawSparkline(canvas, hist) {
        var w = canvas.width, h = canvas.height, n = hist.length
        if (w < 20 || h < 20 || n < 1) return

        var ctx = canvas.getContext("2d")
        ctx.clearRect(0, 0, w, h)

        var padR = 6  // right padding for terminal dot clearance
        var padB = 4  // bottom padding
        var padT = 4  // top padding
        var plotW = w - padR
        var plotH = h - padT - padB
        var baseY = h - padB

        // grid lines (25%, 50%, 75%)
        ctx.strokeStyle = card.theme.surface0
        ctx.lineWidth = 0.5
        for (var g = 25; g <= 75; g += 25) {
            var gy = baseY - (g / 100) * plotH
            ctx.beginPath()
            ctx.moveTo(0, gy)
            ctx.lineTo(w, gy)
            ctx.stroke()
        }

        if (n === 1) {
            var sx = plotW / 2
            var sy = baseY - (hist[0] / 100) * plotH
            ctx.fillStyle = canvas.lineClr
            ctx.beginPath()
            ctx.arc(sx, sy, 2.5, 0, 2 * Math.PI)
            ctx.fill()
            return
        }

        var stepX = plotW / (n - 1)

        // ── filled area ──
        ctx.beginPath()
        ctx.moveTo(0, baseY)
        ctx.lineTo(0, baseY - (hist[0] / 100) * plotH)
        for (var i = 1; i < n; i++)
            ctx.lineTo(i * stepX, baseY - (hist[i] / 100) * plotH)
        ctx.lineTo((n - 1) * stepX, baseY)
        ctx.closePath()
        ctx.fillStyle = canvas.fillClr
        ctx.fill()

        // ── line ──
        ctx.beginPath()
        ctx.moveTo(0, baseY - (hist[0] / 100) * plotH)
        for (var j = 1; j < n; j++)
            ctx.lineTo(j * stepX, baseY - (hist[j] / 100) * plotH)
        ctx.strokeStyle = canvas.lineClr
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()

        // ── terminal dot ──
        var lx = (n - 1) * stepX
        var ly = baseY - (hist[n - 1] / 100) * plotH
        ctx.fillStyle = canvas.lineClr
        ctx.beginPath()
        ctx.arc(lx, ly, 2.5, 0, 2 * Math.PI)
        ctx.fill()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Text {
            text: card.label
            color: card.lineClr
            font.pixelSize: card.theme.fontSize - 1
            font.bold: true
            font.family: card.theme.font
            Layout.preferredWidth: 24
            verticalAlignment: Text.AlignVCenter
        }

        Canvas {
            id: spark
            Layout.fillWidth: true
            Layout.fillHeight: true
            property string lineClr: card.lineClr
            property string fillClr: card.fillClr
            onPaint: card.drawSparkline(this, card.history)
        }

        ColumnLayout {
            Layout.preferredWidth: 54
            spacing: 1

            Text {
                text: card.pct + "%"
                color: card.lineClr
                font.pixelSize: card.theme.fontSize + 1
                font.bold: true
                font.family: card.theme.font
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: card.hasData ? "L" + card.minVal + " H" + card.maxVal : "—"
                color: card.theme.subtext0
                font.pixelSize: card.theme.fontSize - 2
                font.family: card.theme.font
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: card.subText
                color: card.subColor
                font.pixelSize: card.theme.fontSize - 2
                font.family: card.theme.font
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
                visible: card.subVisible
            }
        }
    }
}
