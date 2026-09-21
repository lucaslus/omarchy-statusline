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
    FileView {
        path: decodeURIComponent(Qt.resolvedUrl("manifest.json").toString().replace(/^file:\/\//, ""))
        JsonAdapter {
            id: manifestData
            property string version: ""
        }
    }
    component Title: PulseText { font.pixelSize: Style.font.bodySmall; opacity: 0.6; Layout.fillWidth: true; Layout.topMargin: Style.space(6) }
    component Hint: PulseText { Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.7; font.pixelSize: Style.font.bodySmall }
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
        signal clicked()
        implicitWidth: Style.space(160)
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
            model: [{id: "overview", label: "Overview", icon: "▦"}, {id: "compact", label: "Compact", icon: "☰"}, {id: "minimal", label: "Minimal", icon: "−"}, {id: "custom", label: "Custom", icon: "⚙"}]
            Button {
                required property var modelData
                text: modelData.label
                iconText: modelData.icon
                selected: root.preferences.layout === modelData.id
                onClicked: root.change("layout", modelData.id)
            }
        }
    }
    RowLayout {
        visible: root.preferences.layout === "custom"
        Layout.fillWidth: true
        Toggle { Layout.fillWidth: true; label: "⌁  Charts"; checked: root.preferences.graphs; onClicked: root.change("showGraphs", !checked) }
        Toggle { Layout.fillWidth: true; label: "☷  Stacked labels"; checked: root.preferences.stacked; onClicked: root.change("stackedLabels", !checked) }
    }
    RowLayout {
        visible: root.preferences.layout === "custom" && root.preferences.graphs
        Layout.fillWidth: true
        PulseText { text: "Chart width"; Layout.fillWidth: true }
        Button { text: "−"; enabled: root.preferences.chartWidth > 20; onClicked: root.change("chartWidth", root.preferences.chartWidth - 5) }
        PulseText { text: root.preferences.chartWidth + " px" }
        Button { text: "+"; enabled: root.preferences.chartWidth < 80; onClicked: root.change("chartWidth", root.preferences.chartWidth + 5) }
    }
    Title { text: "Metrics & order" }
    Repeater {
        model: root.preferences.metrics.concat(LayoutModel.metricIds.filter(id => root.preferences.metrics.indexOf(id) < 0))
        RowLayout {
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
            Rectangle {
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                radius: Style.cornerRadius
                color: Qt.alpha(parent.metricColor, 0.10)
                opacity: parent.selected ? 1 : 0.45
                PulseIcon { anchors.centerIn: parent; width: Style.space(22); height: Style.space(22); name: modelData; ink: parent.parent.metricColor }
            }
            Toggle {
                Layout.fillWidth: true
                label: ({cpu: "CPU", memory: "Memory", gpu: "GPU", heat: "CPU / GPU temperatures", disk: "Disk /"})[modelData]
                checked: parent.selected
                enabled: !checked || root.preferences.metrics.length > 1
                onClicked: root.toggleMetric(modelData)
            }
            Button { text: "↑"; tooltipText: "Move earlier"; enabled: parent.selected && root.preferences.metrics.indexOf(modelData) > 0; onClicked: root.move(modelData, -1) }
            Button { text: "↓"; tooltipText: "Move later"; enabled: parent.selected && root.preferences.metrics.indexOf(modelData) < root.preferences.metrics.length - 1; onClicked: root.move(modelData, 1) }
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
        spacing: Style.space(8)
    Title { text: root.installedVersion ? "Version " + root.installedVersion : "Omarchy Statusline" }
    Hint { text: "Manage updates through Omarchy’s plugin manager." }
    Hint {
        objectName: "pulseUpdateInstructions"
        text: "For a normal installation, run in a terminal:\nomarchy plugin update lucas.system-pulse"
    }
    Hint { text: "Development installations: update your source checkout manually. Reload Omarchy Shell after updating; this restarts the whole shell." }
    Flow {
        Layout.fillWidth: true; spacing: Style.space(7)
        Button {
            iconText: "↗"; text: "Plugin marketplace"
            onClicked: Qt.openUrlExternally("https://plugins.omarchy.org/")
        }
        Button { iconText: "↻"; text: "Reload shell"; tooltipText: "Restart Omarchy Shell to apply updates"; onClicked: Quickshell.execDetached(["omarchy", "restart", "shell"]) }
    }
    }
}
