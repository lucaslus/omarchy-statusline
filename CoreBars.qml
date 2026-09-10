import QtQuick

Canvas {
    id: root
    property var values: []
    property color ink: "#ffffff"
    property real spacing: 2
    onValuesChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const step = width / Math.max(1, values.length)
        const gap = Math.min(spacing, step * 0.3)
        for (let i = 0; i < values.length; i++) {
            ctx.fillStyle = Qt.alpha(ink, 0.12)
            ctx.fillRect(i * step, 0, step - gap, height)
            if (values[i] === null || values[i] === undefined) continue
            const barHeight = Math.max(1, height * Math.max(0, Math.min(100, values[i])) / 100)
            ctx.fillStyle = ink
            ctx.fillRect(i * step, height - barHeight, step - gap, barHeight)
        }
    }
}
