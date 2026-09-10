import QtQuick
import Quickshell
import "Pulse" as Pulse
import "Pulse/History.js" as History
import "Pulse/Layout.js" as LayoutModel
ShellRoot {
    id: app
    property int stage: 0
    property int failures: 0
    function check(condition, message) {
        if (!condition) { failures++; console.error("PULSE_TEST_FAIL", message) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        if (!item.children) return null
        for (const child of item.children) { const found = find(child, name); if (found) return found }
        return null
    }
    Item {
        id: barFixture
        width: 2194; height: 36
        Item {
            property string region: "center"
            property string moduleName: "clock"
            x: parent.width / 2 - width / 2; width: 180; height: 36
        }
        Item {
            id: trayFixture
            property string region: "right"
            property string moduleName: "tray"
            x: parent.width - width - 8; width: 240; height: 36
        }
        Item {
            property string region: "right"
            property string moduleName: "lucas.system-pulse"
            width: first.item ? first.item.implicitWidth : 0
            x: trayFixture.x - width
            Loader {
                id: first
                sourceComponent: Component {
                    Pulse.Widget {
                        id: fittedWidget
                        availableWidth: LayoutModel.availableWidth(fittedWidget, barFixture, 12)
                        settings: ({layout: "custom"})
                    }
                }
            }
        }
    }
    Loader { id: second; active: false; sourceComponent: Component { Pulse.Widget {} } }
    Pulse.Detail {
        id: detail
        width: 620; height: 300
        onSaveRequested: values => settings = Object.assign({}, settings, values)
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            app.stage++
            const scroll = app.find(detail, "pulseScroll")
            const page = app.find(detail, "pulseSettings")
            if (app.stage === 1) {
                app.check(Pulse.Metrics.consumers === 1 && Pulse.Metrics.collector.running, "first consumer starts collector")
                const sample = {time: 1000, cpu: 90, memory: {percent: 20}, gpu: {id: 'a', percent: 90}}
                let points = []
                for (let i = 0; i < 31; i++) { sample.time = 1000 + i; points = History.append(points, Object.assign({}, sample)) }
                sample.time = 5000; sample.cpu = 5
                points = History.append(points, sample)
                app.check(points.length === 1 && History.series(points, 5000).cpu[0].value === 5, "one-hour gap discards old points")
                app.check(History.series(points, 5061).cpu.length === 0, "stale points disappear while disconnected")
                app.check(LayoutModel.normalize({metrics: ['invalid', 'cpu', 'cpu']}).metrics.join() === 'cpu', "layout validates metric IDs")
                app.check(!LayoutModel.normalize({layout:'minimal'}).graphs, "minimal hides charts")
                app.check(first.item.fittedGraphs && first.item.fittedCount === 5, "wide monitor keeps all charts")
                barFixture.width = 1234
                scroll.contentY = 200
                detail.showSettings = true
                second.active = true
            }
            if (app.stage === 2) {
                app.check(!first.item.fittedGraphs, "portrait monitor drops graphs")
                app.check(first.item.implicitWidth <= first.item.availableWidth, "portrait widget fits remaining space")
                app.check(first.item.parent.parent.x >= barFixture.width / 2 + 90 + 12, "portrait widget clears centered clock")
                trayFixture.width = 460
                app.check(first.item.fittedCount === 0, "crowded tray falls back to launcher")
                app.check(first.item.implicitWidth <= first.item.availableWidth, "launcher fits tiny remaining space")
                trayFixture.width = 240
                barFixture.width = 2194
                app.check(scroll.contentY === 0, "settings resets scroll")
                app.check(scroll.contentHeight === page.implicitHeight, "settings uses its own scroll height")
                page.change("layout", "minimal")
                app.check(detail.settings.layout === 'minimal', "settings emits persistable values")
                page.change("detailLayout", "compact")
                app.check(detail.compactDetails, "compact detail preference saves")
                page.toggleMetric("heat")
                app.check(detail.settings.metrics.indexOf("heat") < 0, "metric visibility saves")
                page.move("gpu", -1)
                app.check(detail.settings.metrics[1] === 'gpu', "metric order saves")
                app.check(Pulse.Metrics.consumers === 2, "two monitors share collector")
                app.check(first.item.fittedGraphs && first.item.fittedCount === 5, "widening restores original layout")
                app.check(first.item.settings.layout === "custom", "automatic fitting preserves preferences")
                first.active = false
            }
            if (app.stage === 3) {
                app.check(Pulse.Metrics.consumers === 1 && Pulse.Metrics.collector.running, "one monitor remaining keeps collector")
                second.active = false
            }
            if (app.stage === 5) {
                app.check(Pulse.Metrics.consumers === 0 && !Pulse.Metrics.collector.running && !Pulse.Metrics.watchdog.running, "last consumer stops process and retries")
                Pulse.Metrics.initialized = false
                Pulse.Metrics.attach({autoStart:false})
                app.check(!Pulse.Metrics.sessionEnabled && !Pulse.Metrics.collector.running, "autostart off starts paused")
                Pulse.Metrics.setRunning(true)
            }
            if (app.stage === 6) {
                app.check(Pulse.Metrics.collector.running, "manual start works")
                Pulse.Metrics.setRunning(false)
            }
            if (app.stage === 8) {
                app.check(!Pulse.Metrics.collector.running && !Pulse.Metrics.watchdog.running, "session exit stays stopped")
                Pulse.Metrics.detach()
                if (app.failures === 0) console.log("PULSE_TEST_PASS")
                Qt.quit()
            }
        }
    }
}
