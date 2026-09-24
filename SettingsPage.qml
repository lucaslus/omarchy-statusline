import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "Layout.js" as LayoutModel
import "."

ColumnLayout {
    id: root
    property var settings: ({})
    property string category: "layout"
    property string saveError: ""
    readonly property string installedVersion: manifestData.version
    readonly property var preferences: LayoutModel.normalize(settings)
    readonly property var gpus: LayoutModel.adapters(Metrics.sample)
    signal saveRequested(var values)
    signal closeRequested()
    spacing: Style.space(8)

    function change(key, value) { const v = {}; v[key] = value; saveRequested(v) }
    function toggleMetric(id) {
        let ids = preferences.metrics.slice()
        if (ids.indexOf(id) >= 0) { if (ids.length === 1) return; ids = ids.filter(v => v !== id) }
        else ids.push(id)
        change("metrics", ids)
    }
    function move(id, delta) {
        const ids = preferences.metrics.slice()
        const i = ids.indexOf(id), next = i + delta
        if (i < 0 || next < 0 || next >= ids.length) return
        const other = ids[next]; ids[next] = id; ids[i] = other
        change("metrics", ids)
    }
    function toggleGpu(key, id) {
        const current = Object.assign({}, settings[key] || {})
        current[id] = current[id] === false
        change(key, current)
    }
    FileView {
        path: decodeURIComponent(Qt.resolvedUrl("manifest.json").toString().replace(/^file:\/\//, ""))
        JsonAdapter {
            id: manifestData
            property string version: ""
        }
    }
    component Title: PulseText { font.pixelSize: Style.font.bodySmall; opacity: 0.6; Layout.fillWidth: true; Layout.topMargin: Style.space(6) }
    component Hint: PulseText { Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.7; font.pixelSize: Style.font.bodySmall }
    component UpdateCard: Rectangle {
        id: card
        property string heading: ""
        property string description: ""
        property string command: ""
        property color tone: Color.accent
        Layout.fillWidth: true
        implicitHeight: cardBody.implicitHeight + Style.space(20)
        radius: Style.cornerRadius
        color: Qt.alpha(tone, 0.08)
        border.width: 1
        border.color: Qt.alpha(tone, 0.3)
        ColumnLayout {
            id: cardBody
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(5)
            PulseText { text: card.heading; color: card.tone; font.bold: true; Layout.fillWidth: true }
            PulseText { objectName: card.command ? "pulseUpdateCommand" : ""; visible: !!card.command; text: card.command; color: Color.popups.text; font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
            PulseText { text: card.description; color: Color.popups.text; opacity: 0.75; font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true; wrapMode: Text.Wrap }
        }
    }
    component Button: Ui.Button {
        focusable: true
        fontSize: Style.font.bodySmall
        iconSize: Style.font.body
        horizontalPadding: Style.space(7)
        verticalPadding: Style.space(4)
    }
    component Toggle: Rectangle {
        id: toggle
        property string label: ""
        property bool checked: false
        property bool showLabel: true
        signal clicked()
        implicitWidth: Style.space(showLabel ? 160 : 38)
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: activeFocus || hit.containsMouse ? Qt.alpha(Color.accent, 0.10) : "transparent"
        border.width: activeFocus ? 1 : 0
        border.color: Color.accent
        opacity: enabled ? 1 : 0.45
        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checked: checked
        Accessible.onPressAction: if (enabled) clicked()
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        PulseText {
            visible: toggle.showLabel
            anchors.left: parent.left
            anchors.leftMargin: Style.space(6)
            anchors.right: track.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: toggle.label
        }
        Ui.ToggleSwitch {
            id: track
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            trackHeight: Style.space(14)
            checked: toggle.checked
            interactive: false
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { toggle.forceActiveFocus(); toggle.clicked() }
        }
    }

    PulseText { visible: !!root.saveError; text: root.saveError; color: Color.urgent; Layout.fillWidth: true; wrapMode: Text.Wrap }
    Flow {
        Layout.fillWidth: true
        spacing: Style.space(7)
        Repeater {
            model: [{id:"layout", label:"Layout", icon:"▦"}, {id:"monitoring", label:"Monitoring", icon:"◉"}, {id:"updates", label:"Updates", icon:"↻"}]
            Button {
                required property var modelData
                text: modelData.label
                iconText: modelData.icon
                accent: ({layout: Metrics.palette("blue", "color4", Color.accent), monitoring: Metrics.palette("green", "color2", Color.accent), updates: Metrics.palette("magenta", "color5", Color.accent)})[modelData.id]
                selected: root.category === modelData.id
                onClicked: root.category = modelData.id
            }
        }
    }
    ColumnLayout {
        visible: root.category === "layout"
        Layout.fillWidth: true
        spacing: Style.space(8)
    Title { text: "Bar layout" }
    Flow {
        Layout.fillWidth: true
        spacing: Style.space(7)
        Repeater {
            model: [{id: "default", label: "Default", icon: "⚙"}, {id: "minimal", label: "Minimal", icon: "−"}]
            Button {
                required property var modelData
                objectName: "pulseBarLayout-" + modelData.id
                text: modelData.label
                iconText: modelData.icon
                selected: root.preferences.layout === modelData.id
                onClicked: root.change("layout", modelData.id)
            }
        }
    }
    RowLayout {
        visible: root.preferences.layout === "default"
        Layout.fillWidth: true
        Toggle { Layout.fillWidth: true; label: "⌁  Charts"; checked: root.preferences.graphs; onClicked: root.change("showGraphs", !checked) }
    }
    RowLayout {
        visible: root.preferences.layout === "default" && root.preferences.graphs
        Layout.fillWidth: true
        PulseText { text: "Chart width"; Layout.fillWidth: true }
        Button { text: "−"; enabled: root.preferences.chartWidth > 20; onClicked: root.change("chartWidth", root.preferences.chartWidth - 5) }
        PulseText { text: root.preferences.chartWidth + " px" }
        Button { text: "+"; enabled: root.preferences.chartWidth < 80; onClicked: root.change("chartWidth", root.preferences.chartWidth + 5) }
    }
    Title { text: "Metrics & order" }
    Repeater {
        model: root.preferences.metrics.concat(LayoutModel.metricIds.filter(id => root.preferences.metrics.indexOf(id) < 0))
        ColumnLayout {
            required property string modelData
            readonly property bool selected: root.preferences.metrics.indexOf(modelData) >= 0
            readonly property color metricColor: ({
                cpu: Metrics.palette("green", "color2", Color.accent),
                memory: Metrics.palette("magenta", "color5", Color.accent),
                gpu: Metrics.palette("blue", "color4", Color.accent),
                disk: Metrics.palette("cyan", "color6", Color.accent),
                heat: Metrics.palette("yellow", "color3", Color.urgent)
            })[modelData]
            Layout.fillWidth: true
            spacing: Style.space(4)
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredWidth: Style.space(28)
                    Layout.preferredHeight: Style.space(28)
                    radius: Style.cornerRadius
                    color: Qt.alpha(metricColor, 0.10)
                    opacity: selected ? 1 : 0.45
                    PulseIcon { anchors.centerIn: parent; width: Style.space(22); height: Style.space(22); name: modelData; ink: metricColor }
                }
                Toggle {
                    Layout.fillWidth: true
                    label: ({cpu: "CPU", memory: "Memory", gpu: root.gpus.length > 1 ? "GPU utilization (" + root.gpus.length + ")" : "GPU utilization", heat: "Temperatures", disk: "Disk /"})[modelData]
                    checked: selected
                    enabled: !checked || root.preferences.metrics.length > 1
                    onClicked: root.toggleMetric(modelData)
                }
                Button { text: "↑"; tooltipText: "Move earlier"; enabled: selected && root.preferences.metrics.indexOf(modelData) > 0; onClicked: root.move(modelData, -1) }
                Button { text: "↓"; tooltipText: "Move later"; enabled: selected && root.preferences.metrics.indexOf(modelData) < root.preferences.metrics.length - 1; onClicked: root.move(modelData, 1) }
            }
            Repeater {
                model: modelData === "gpu" ? root.gpus : []
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.leftMargin: Style.space(32)
                    Layout.fillWidth: true
                    spacing: Style.space(5)
                    PulseText {
                        text: "GPU " + (index + 1) + (modelData.name ? " · " + modelData.name : "")
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Style.font.bodySmall
                        opacity: 0.7
                    }
                    PulseText { text: "Load"; font.pixelSize: Style.font.caption; opacity: 0.6 }
                    Toggle {
                        showLabel: false
                        label: "GPU " + (index + 1) + " utilization"
                        checked: LayoutModel.gpuEnabled(root.settings, "gpuVisibility", modelData.id)
                        enabled: selected
                        onClicked: root.toggleGpu("gpuVisibility", modelData.id)
                    }
                    PulseText { text: "Temp"; font.pixelSize: Style.font.caption; opacity: 0.6 }
                    Toggle {
                        showLabel: false
                        label: "GPU " + (index + 1) + " temperature"
                        checked: LayoutModel.gpuEnabled(root.settings, "gpuTemperatureVisibility", modelData.id)
                        enabled: root.preferences.metrics.indexOf("heat") >= 0
                        onClicked: root.toggleGpu("gpuTemperatureVisibility", modelData.id)
                    }
                }
            }
            Toggle {
                visible: modelData === "heat"
                Layout.fillWidth: true
                Layout.leftMargin: Style.space(32)
                label: "CPU temperature"
                checked: root.settings.cpuTemperature !== false
                enabled: selected
                onClicked: root.change("cpuTemperature", !checked)
            }
        }
    }
    Title { text: "Detail panel" }
    RowLayout {
        Layout.fillWidth: true
        Button { iconText: "▦"; text: "Overview"; selected: root.settings.detailLayout !== "compact"; onClicked: root.change("detailLayout", "overview") }
        Button { iconText: "☰"; text: "Compact"; selected: root.settings.detailLayout === "compact"; onClicked: root.change("detailLayout", "compact") }
    }
    Toggle { Layout.fillWidth: true; label: "⌁  History graphs"; checked: root.settings.showHistory !== false; onClicked: root.change("showHistory", !checked) }
    }
    ColumnLayout {
        visible: root.category === "monitoring"
        Layout.fillWidth: true
        spacing: Style.space(8)
    Title { text: "Sampling & startup" }
    RowLayout {
        Layout.fillWidth: true
        PulseText { text: "Sample interval"; Layout.fillWidth: true }
        Repeater {
            model: [1, 2, 5]
            Button { required property int modelData; text: modelData + "s"; selected: Number(root.settings.intervalSeconds ?? 2) === modelData; onClicked: root.change("intervalSeconds", modelData) }
        }
    }
    Toggle {
        Layout.fillWidth: true
        label: "⏻  Start at login"
        checked: root.settings.autoStart !== false
        onClicked: root.change("autoStart", !checked)
    }
    Flow {
        Layout.fillWidth: true; spacing: Style.space(7)
        Button { iconText: Metrics.sessionEnabled ? "Ⅱ" : "▶"; text: Metrics.sessionEnabled ? "Pause" : "Resume"; onClicked: Metrics.setRunning(!Metrics.sessionEnabled) }
        Button { iconText: "↪"; text: "Exit"; enabled: Metrics.sessionEnabled; onClicked: { Metrics.setRunning(false); root.closeRequested() } }
    }
    Hint { text: "Exit stops monitoring; the launch button stays in the bar." }
    Title { text: "Remove from bar" }
    Hint { text: "Re-enable from Omarchy’s plugin settings." }
    Button { iconText: "×"; text: "Disable plugin"; onClicked: Quickshell.execDetached(["omarchy", "plugin", "disable", "lucas.system-pulse"]) }    }
    ColumnLayout {
        visible: root.category === "updates"
        Layout.fillWidth: true
        spacing: Style.space(10)
    RowLayout {
        Layout.fillWidth: true
        PulseText { text: "Installed"; font.pixelSize: Style.font.bodySmall; opacity: 0.7 }
        PulseText { text: root.installedVersion ? "v" + root.installedVersion : "—"; color: Metrics.palette("magenta", "color5", Color.accent); font.bold: true; Layout.fillWidth: true }
    }
    UpdateCard {
        heading: "Update from GitHub"
        command: "omarchy plugin update lucas.system-pulse"
        description: "Run in a terminal. Omarchy uses the GitHub remote saved at installation."
        tone: Metrics.palette("blue", "color4", Color.accent)
    }
    Hint { objectName: "pulseUpdateInstructions"; text: "Local development install? Update its source checkout instead." }
    Flow {
        Layout.fillWidth: true; spacing: Style.space(7)
        Button {
            iconText: "↗"; text: "Omarchy plugin guide"
            accent: Metrics.palette("blue", "color4", Color.accent)
            onClicked: Qt.openUrlExternally("https://omarchy.org/manual/shell-plugins/")
        }
    }
    }
}
