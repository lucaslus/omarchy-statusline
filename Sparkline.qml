import QtQuick

Canvas {
    id: root
    property var values: []
    property color ink: "#ffffff"
    property real ceiling: 100
    property bool grid: false
    property real now: Metrics.now
    property real maxGap: Metrics.intervalSeconds * 1.8
    onNowChanged: requestPaint()
    onValuesChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (grid) {
            ctx.strokeStyle = Qt.alpha(ink, 0.10)
            ctx.lineWidth = 1
            for (let x = 0; x < width; x += width / 12) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
            for (let y = 0; y < height; y += height / 4) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
        }
        ctx.strokeStyle = ink
        ctx.lineWidth = 1.4
        let started = false
        let previousTime = 0
        ctx.beginPath()
        for (let i = 0; i < values.length; i++) {
            if (values[i].value === null || values[i].value === undefined) { started = false; continue }
            const x = width * Math.max(0, Math.min(1, (values[i].time - now + 60) / 60))
            const y = height - 2 - Math.max(0, Math.min(1, values[i].value / ceiling)) * (height - 4)
            if (values[i].time - previousTime > maxGap) started = false
            previousTime = values[i].time
            if (!started) { ctx.moveTo(x, y); started = true } else ctx.lineTo(x, y)
        }
        ctx.stroke()
    }
}
