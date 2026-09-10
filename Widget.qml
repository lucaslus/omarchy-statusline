import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import "Layout.js" as Layout
import "."

Panel {
    id: root
    moduleName: "lucas.system-pulse"
    manageIpc: false
    property bool attached: false
    property string settingsError: ""
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property var preferences: Layout.normalize(settings)
    readonly property var hostWindow: QsWindow.window
    property real availableWidth: Layout.availableWidth(root, hostWindow ? hostWindow.contentItem : null, Style.space(12))
    readonly property bool fittedGraphs: preferences.graphs && fullWidth <= availableWidth
    readonly property var metricIds: preferences.metrics.reduce((ids, id) => ids.concat(id === "heat" ? ["cpuHeat", "gpuHeat"] : [id]), [])
    readonly property real fullWidth: measuredWidth(metricIds.length, preferences.graphs)
    readonly property int fittedCount: {
        for (let count = metricIds.length; count > 0; count--)
            if (measuredWidth(count, fittedGraphs) <= availableWidth) return count
        return 0
    }
    function measuredWidth(count, graphs) {
        let result = Style.space(12) + Math.max(0, count - 1) * Style.space(12)
        for (let i = 0; i < count; i++) {
            const metric = metrics[metricIds[i]]
            const text = (preferences.stacked ? "" : metric.name + " ") + metric.value
            const labelWidth = Math.ceil(Math.max(bodyMetrics.advanceWidth(text), preferences.stacked ? captionMetrics.advanceWidth(metric.name) : 0))
            result += labelWidth + (graphs ? Style.space(5 + preferences.chartWidth) : 0)
        }
        return result
    }
    FontMetrics { id: bodyMetrics; font.family: Style.font.family; font.pixelSize: Style.font.body }
    FontMetrics { id: captionMetrics; font.family: Style.font.family; font.pixelSize: Style.font.caption }
    readonly property color cpuColor: Metrics.palette("green", "color2", Color.accent)
    readonly property color memoryColor: Metrics.palette("magenta", "color5", Color.accent)
    readonly property color gpuColor: Metrics.palette("blue", "color4", Color.accent)
    readonly property color heatColor: Metrics.palette("yellow", "color3", Color.urgent)
    readonly property var s: Metrics.sample
    readonly property var metrics: ({
        cpu: {name: "CPU", value: Metrics.percent(s.cpu), ink: cpuColor},
        disk: {name: "DISK", value: Metrics.percent((s.disk || {}).percent), ink: Metrics.palette("cyan", "color6", cpuColor)},
        memory: {name: "MEM", value: Metrics.percent(s.memory.percent), ink: memoryColor},
        gpu: {name: "GPU", value: Metrics.percent(s.gpu.percent), ink: gpuColor},
        cpuHeat: {name: "CPU", value: Metrics.temp(s.cpuTemperature), ink: heatColor},
        gpuHeat: {name: "GPU", value: Metrics.temp(s.gpu.temperature), ink: heatColor}
    })
    implicitWidth: vertical ? Style.bar.sizeVertical : !Metrics.sessionEnabled || fittedCount === 0 ? Math.min(availableWidth, Style.space(42)) : Math.min(availableWidth, measuredWidth(fittedCount, fittedGraphs))
    implicitHeight: vertical ? Style.space(Metrics.sessionEnabled ? 62 : 30) : (bar ? bar.barSize : Style.bar.sizeHorizontal)
    Component.onCompleted: { Metrics.attach(settings); attached = true }
    Component.onDestruction: if (attached) Metrics.detach()
    onSettingsChanged: if (attached) Metrics.configure(settings)
    function save(values) {
        const next = Object.assign({}, settings, values)
        if (JSON.stringify(next) === JSON.stringify(settings)) { settingsError = ""; return }
        const api = bar ? bar.shell : null
        if (api && api.updateEntryInline(moduleName, next)) settingsError = ""
        else settingsError = "Could not save settings. Try again from the Omarchy bar."
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        clip: true
        bar: root.bar
        text: "Omarchy Statusline"
        labelVisible: false
        tooltipText: !Metrics.sessionEnabled ? "Omarchy Statusline paused · click to open" : Metrics.stale ? "Omarchy Statusline · telemetry unavailable" : "Omarchy Statusline · click for details"
        onPressed: b => { if (b === Qt.RightButton) { detail.showSettings = true; root.open() } else root.toggle() }
        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            radius: Style.cornerRadius
            color: root.opened || button.tooltipHovered ? Qt.alpha(Color.foreground, 0.07) : "transparent"
            border.color: root.opened ? Qt.alpha(Color.accent, 0.4) : "transparent"
        }
        PulseText { visible: !Metrics.sessionEnabled || (!root.vertical && root.fittedCount === 0); anchors.centerIn: parent; text: "◌"; color: root.barForeground }
        Row {
            id: line
            anchors.centerIn: parent
            spacing: Style.space(12)
            visible: !root.vertical && Metrics.sessionEnabled && root.fittedCount > 0
            opacity: Metrics.stale ? 0.4 : 1
            Repeater {
                model: root.metricIds.slice(0, root.fittedCount)
                Row {
                    required property string modelData
                    readonly property var metric: root.metrics[modelData]
                    spacing: Style.space(5)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        PulseText { text: metric.name; color: root.barForeground; opacity: 0.65; font.pixelSize: Style.font.caption; visible: root.preferences.stacked }
                        PulseText { text: (!root.preferences.stacked ? metric.name + " " : "") + metric.value; color: metric.ink }
                    }
                    Item {
                        width: Style.space(root.preferences.chartWidth)
                        height: Style.space(root.preferences.stacked ? 22 : 14)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.fittedGraphs
                        CoreBars { anchors.fill: parent; visible: modelData === "cpu"; values: root.s.cores; ink: root.cpuColor; spacing: 1 }
                        Meter { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: Style.space(6); visible: modelData === "memory" || modelData === "disk"; value: modelData === "disk" ? (root.s.disk || {}).percent : root.s.memory.percent; ink: metric.ink }
                        Sparkline { anchors.fill: parent; visible: modelData === "gpu" || modelData === "cpuHeat" || modelData === "gpuHeat"; values: modelData === "gpu" ? Metrics.history.gpu : (modelData === "gpuHeat" ? Metrics.history.gpuTemp : Metrics.history.cpuTemp); ink: metric.ink }
                    }
                }
            }
        }
        Column {
            visible: root.vertical && Metrics.sessionEnabled
            anchors.centerIn: parent
            opacity: Metrics.stale ? 0.4 : 1
            PulseText { text: "CPU"; font.pixelSize: Style.font.caption; color: root.barForeground }
            PulseText { text: Metrics.percent(root.s.cpu); font.pixelSize: Style.font.caption; color: root.cpuColor }
            PulseText { text: "MEM"; font.pixelSize: Style.font.caption; color: root.barForeground }
            PulseText { text: Metrics.percent(root.s.memory.percent); font.pixelSize: Style.font.caption; color: root.memoryColor }
        }
    }
    KeyboardPanel {
        id: panel
        anchorItem: button; owner: root; bar: root.bar; open: root.opened
        focusTarget: detail
        contentWidth: fittedContentWidth(Style.space(440))
        contentHeight: fittedContentHeight(detail.implicitHeight, Style.space(760))
        Detail {
            id: detail
            anchors.fill: parent
            settings: root.settings
            settingsError: root.settingsError
            onSaveRequested: values => root.save(values)
            cpuColor: root.cpuColor; memoryColor: root.memoryColor
            gpuColor: root.gpuColor; heatColor: root.heatColor
            onCloseRequested: root.close()
        }
    }
}
