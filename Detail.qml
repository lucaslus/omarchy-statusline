import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import "."

FocusScope {
    id: root
    // Keep the outer frame stable when switching between System and Settings.
    implicitHeight: Style.space(558)
    property var settings: ({})
    readonly property bool compactDetails: settings.detailLayout === "compact"
    property string settingsError: ""
    signal saveRequested(var values)
    property color cpuColor: Color.accent
    property color memoryColor: Color.accent
    property color gpuColor: Color.accent
    property color heatColor: Color.urgent
    property bool showSettings: false
    readonly property bool showHistory: settings.showHistory !== false
    onShowSettingsChanged: scroll.contentY = 0
    signal closeRequested()
    readonly property var s: Metrics.sample
    readonly property var disk: s.disk || ({})
    readonly property color diskColor: Metrics.palette("cyan", "color6", Color.accent)
    Keys.onEscapePressed: { if (showSettings) showSettings = false; else closeRequested() }

    component Separator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Color.foreground, 0.14)
    }
    component Action: Rectangle {
        id: action
        property string label: ""
        signal triggered()
        implicitWidth: labelText.implicitWidth + Style.space(22)
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: mouse.containsMouse || activeFocus ? Qt.alpha(Color.accent, 0.14) : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: triggered()
        Keys.onSpacePressed: triggered()
        PulseText { id: labelText; anchors.centerIn: parent; text: action.label }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: action.triggered() }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)
        RowLayout {
            Layout.fillWidth: true
            PulseText { text: root.showSettings ? "Settings" : "System"; font.pixelSize: Style.font.heading; Layout.fillWidth: true }
            Rectangle { visible: !root.showSettings; width: 5; height: 5; radius: 3; color: Metrics.stale ? Color.urgent : root.cpuColor }
            PulseText { visible: !root.showSettings; text: Metrics.stateLabel; opacity: 0.65; font.pixelSize: Style.font.caption }
            Action { label: "×"; onTriggered: root.closeRequested() }
        }
        Separator {}
        RowLayout {
            visible: !root.showSettings && !Metrics.sessionEnabled
            Layout.fillWidth: true
            PulseText { text: "Monitoring is paused"; Layout.fillWidth: true }
            Action { label: "Start monitoring"; onTriggered: Metrics.setRunning(true) }
        }
        PulseText { visible: !!Metrics.error; text: Metrics.error; color: Color.urgent; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Flickable {
            id: scroll
            objectName: "pulseScroll"
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: root.showSettings ? settingsPage.implicitHeight : body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: body
                width: scroll.width
                spacing: Style.space(root.compactDetails ? 8 : 12)
                visible: !root.showSettings
                opacity: Metrics.stale ? 0.5 : 1
                Repeater {
                    model: [
                        {label: "CPU" + (root.s.cpuModel ? " · " + root.s.cpuModel : ""), icon: "cpu", value: Metrics.percent(root.s.cpu), sub: Metrics.temp(root.s.cpuTemperature), ink: root.cpuColor, history: Metrics.history.cpu, type: "cpu"},
                        {label: "Memory", icon: "memory", value: Metrics.percent(root.s.memory.percent), sub: Metrics.gib(root.s.memory.used) + " / " + Metrics.gib(root.s.memory.total) + " GiB", ink: root.memoryColor, history: Metrics.history.memory, type: "memory"},
                        {label: "GPU" + (root.s.gpu.name ? " · " + root.s.gpu.name : " · unavailable"), icon: "gpu", value: Metrics.percent(root.s.gpu.percent), sub: Metrics.temp(root.s.gpu.temperature), ink: root.gpuColor, history: Metrics.history.gpu, type: "gpu"}
                    ]
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        PulseText {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.pixelSize: Style.font.bodySmall
                            ToolTip.visible: modelHover.hovered
                            ToolTip.text: modelData.label
                            ToolTip.delay: 400
                            HoverHandler { id: modelHover }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(10)
                            PulseIcon { name: modelData.icon; ink: modelData.ink; Layout.preferredWidth: Style.space(22); Layout.preferredHeight: Style.space(22); Layout.alignment: Qt.AlignTop }
                            ColumnLayout {
                                Layout.preferredWidth: Style.space(140)
                                Layout.minimumWidth: Style.space(85)
                                PulseText { text: modelData.value; color: modelData.ink; font.pixelSize: root.compactDetails ? Style.font.heading : Style.font.display }
                                PulseText { text: modelData.sub; color: modelData.type === "memory" ? Color.popups.text : root.heatColor; font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: Style.space(160)
                                Layout.fillWidth: true
                                CoreBars { visible: modelData.type === "cpu"; Layout.fillWidth: true; Layout.preferredHeight: Style.space(root.compactDetails ? 28 : 36); values: root.s.cores; ink: root.cpuColor; spacing: 2 }
                                PulseText { visible: modelData.type === "gpu"; text: "VRAM " + Metrics.gib(root.s.gpu.used) + " / " + Metrics.gib(root.s.gpu.total) + " GiB"; Layout.fillWidth: true; font.pixelSize: Style.font.bodySmall }
                                Meter { visible: modelData.type !== "cpu"; Layout.fillWidth: true; Layout.preferredHeight: Style.space(10); value: modelData.type === "memory" ? root.s.memory.percent : (root.s.gpu.total ? 100 * root.s.gpu.used / root.s.gpu.total : null); ink: modelData.ink }
                                PulseText {
                                    Layout.fillWidth: true; font.pixelSize: Style.font.caption; opacity: 0.65
                                    text: modelData.type === "cpu" ? root.s.cores.length + " cores" : modelData.type === "memory" ? "Available " + Metrics.gib(root.s.memory.total == null || root.s.memory.used == null ? null : root.s.memory.total - root.s.memory.used) + " GiB" : (root.s.gpu.power == null ? "—" : Math.round(root.s.gpu.power)) + " W · " + (root.s.gpu.fan == null ? "—" : Math.round(root.s.gpu.fan)) + " RPM"
                                }
                            }
                        }
                        Sparkline {
                            visible: root.showHistory && !root.compactDetails
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(24)
                            values: modelData.history
                            ink: modelData.ink
                        }
                        Separator {}
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PulseIcon { name: "disk"; ink: root.diskColor; Layout.preferredWidth: Style.space(22); Layout.preferredHeight: Style.space(22) }
                    PulseText { text: "Disk /"; Layout.fillWidth: true }
                    PulseText { text: Metrics.percent(root.disk.percent); color: root.diskColor }
                }
                Meter { Layout.fillWidth: true; Layout.preferredHeight: Style.space(6); value: root.disk.percent; ink: root.diskColor }
                PulseText { text: Metrics.gib(root.disk.used) + " / " + Metrics.gib(root.disk.total) + " GiB · " + Metrics.gib(root.disk.free) + " GiB free"; font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true }
                PulseText {
                    text: "All drives  ↓ " + Metrics.rate(root.disk.readRate) + "  ↑ " + Metrics.rate(root.disk.writeRate)
                    font.pixelSize: Style.font.bodySmall
                    Layout.fillWidth: true
                    opacity: 0.7
                }
                Separator {}
                PulseText { text: "Temperatures"; font.pixelSize: Style.font.bodySmall }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(28)
                    Repeater {
                        model: [{label: "CPU", value: root.s.cpuTemperature, history: Metrics.history.cpuTemp}, {label: "GPU", value: root.s.gpu.temperature, history: Metrics.history.gpuTemp}, {label: "HOTSPOT", value: root.s.gpu.hotspot, history: Metrics.history.hotspot}]
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            PulseText { text: modelData.label; opacity: 0.65; font.pixelSize: Style.font.caption }
                            PulseText { text: Metrics.temp(modelData.value); color: modelData.value >= 85 ? Color.urgent : root.heatColor; font.pixelSize: Style.font.heading }
                            Sparkline { visible: root.showHistory; Layout.fillWidth: true; Layout.preferredHeight: Style.space(root.compactDetails ? 16 : 20); values: modelData.history; ink: root.heatColor; ceiling: 110 }
                        }
                    }
                }
            }
            SettingsPage {
                id: settingsPage
                objectName: "pulseSettings"
                visible: root.showSettings
                width: scroll.width
                settings: root.settings
                saveError: root.settingsError
                onCategoryChanged: scroll.contentY = 0
                onSaveRequested: values => root.saveRequested(values)
                onCloseRequested: root.closeRequested()
            }
        }
        Separator {}
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Action { label: root.showSettings ? "← Back" : "⚙ Settings"; onTriggered: root.showSettings = !root.showSettings }
        }
    }
}
