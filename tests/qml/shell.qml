import QtQuick
import Quickshell
import "Pulse" as Pulse
import "Pulse/History.js" as History
import "Pulse/Layout.js" as LayoutModel
ShellRoot {
    id: app
    property int stage: 0
    property int failures: 0
    property var multiGpuSample: ({})
    function check(condition, message) {
        if (!condition) { failures++; console.error("PULSE_TEST_FAIL", message) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        if (!item.children) return null
        for (const child of item.children) { const found = find(child, name); if (found) return found }
        return null
    }
    function visibleTexts(item) {
        if (!item.visible) return []
        let result = typeof item.text === "string" ? [item.text] : []
        if (item.children) for (const child of item.children) result = result.concat(visibleTexts(child))
        return result
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
                        settings: ({layout: "default"})
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
                const adapters = [
                    {id: 'card0', name: 'Integrated', percent: 12, temperature: 42, hotspot: null, used: 1024, total: 4096},
                    {id: 'card1', name: 'Discrete', percent: 84, temperature: 69, hotspot: 81, used: 2048, total: 8192}
                ]
                const multi = [
                    {time: 100, cpu: 15, cpuTemperature: 40, memory: {percent: 20}, gpu: adapters[0], gpus: adapters},
                    {time: 101, cpu: 20, cpuTemperature: 41, memory: {percent: 21}, gpu: adapters[0], gpus: [adapters[0], Object.assign({}, adapters[1], {percent: 91})]}
                ]
                const histories = History.series(multi, 101).gpus
                app.check(histories.card0.load[1].value === 12 && histories.card1.load[1].value === 91, "GPU histories stay separate")
                app.check(histories.card0.temperature[0].value === 42 && histories.card1.hotspot[0].value === 81, "GPU temperatures stay separate")
                const missing = Object.assign({}, multi[0], {gpus: [adapters[0]]})
                const joined = History.series([missing, multi[1]], 101).gpus
                app.check(joined.card1.load[0].value === null && joined.card1.load[1].value === 91, "new GPU starts with a history gap")
                app.multiGpuSample = Object.assign({}, multi[1], {disk: {}, palette: {}, cores: []})
                Pulse.Metrics.sample = app.multiGpuSample
                Pulse.Metrics.history = History.series(multi, 101)
                app.check(detail.gpuRows.length === 2 && detail.gpuRows[0].gpu.id === 'card0' && detail.gpuRows[1].gpu.id === 'card1', "detail has both GPUs")
                app.check(app.find(detail, "pulseGpuDetail-card0") && app.find(detail, "pulseGpuDetail-card1"), "detail renders both GPU rows")
                const discrete = app.find(detail, "pulseGpuDetail-card1")
                app.check(discrete && app.visibleTexts(discrete).includes("Temp 69°C") && app.visibleTexts(discrete).includes("Hotspot 81°C"), "GPU temperatures appear in its own detail row")
                app.check(app.visibleTexts(detail).includes("Temp 41°C"), "CPU temperature appears in CPU detail row")
                app.check(!app.visibleTexts(detail).includes("Temperatures"), "detail has no separate temperature section")
                app.check(LayoutModel.normalize({metrics: ['invalid', 'cpu', 'cpu']}).metrics.join() === 'cpu', "layout validates metric IDs")
                app.check(LayoutModel.normalize({}).layout === 'default' && LayoutModel.normalize({layout: 'custom'}).layout === 'default' && LayoutModel.normalize({layout: 'compact'}).layout === 'default', "default layout accepts legacy presets")
                app.check(!LayoutModel.normalize({layout:'minimal'}).graphs, "minimal hides charts")
                app.check(first.item.metricIds.join() === 'cpu,memory,gpu:card0,gpu:card1,cpuHeat,gpuHeat:card0,gpuHeat:card1', "bar expands both GPUs and temperatures")
                app.check(first.item.metrics['gpu:card0'].name === 'GPU1' && first.item.metrics['gpu:card1'].name === 'GPU2', "bar labels both GPUs")
                app.check(first.item.fittedCount === 7, "wide monitor keeps all GPU readouts: " + first.item.fittedCount + "/" + first.item.availableWidth + "/" + first.item.fullWidth)
                barFixture.width = 1234
                scroll.contentY = 200
                detail.showSettings = true
                second.active = true
            }
            if (app.stage === 2) {
                Pulse.Metrics.sample = app.multiGpuSample
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
                app.check(page.gpus.length === 2 && app.visibleTexts(page).includes('GPU 1 · Integrated') && app.visibleTexts(page).includes('GPU 2 · Discrete'), "settings identifies both GPUs")
                page.toggleGpu('gpuVisibility', 'card1')
                app.check(detail.settings.gpuVisibility.card1 === false, "GPU visibility saves by adapter ID")
                page.toggleGpu('gpuTemperatureVisibility', 'card0')
                app.check(detail.settings.gpuTemperatureVisibility.card0 === false, "GPU temperature visibility saves by adapter ID")
                first.item.settings = {layout: 'default', gpuVisibility: {card1: false}, gpuTemperatureVisibility: {card0: false}, cpuTemperature: false}
                app.check(first.item.metricIds.join() === 'cpu,memory,gpu:card0,gpuHeat:card1', "bar respects per-device settings")
                first.item.settings = {layout: 'default'}
                Pulse.Metrics.sample = Object.assign({}, app.multiGpuSample, {gpus: [app.multiGpuSample.gpus[0]]})
                app.check(first.item.metricIds.join() === 'cpu,memory,gpu:card0,cpuHeat,gpuHeat:card0' && first.item.metrics['gpu:card0'].name === 'GPU', "single GPU keeps its original bar label")
                Pulse.Metrics.sample = app.multiGpuSample
                page.category = "updates"
                app.check(page.installedVersion.length > 0, "settings reads installed version without updater process")
                const updateGuide = app.find(page, "pulseUpdateInstructions")
                app.check(updateGuide && updateGuide.visible && updateGuide.text.indexOf("omarchy plugin update lucas.system-pulse") >= 0, "updates page directs users to host plugin manager")
                page.category = "layout"
                page.change("layout", "minimal")
                app.check(detail.settings.layout === 'minimal', "settings emits persistable values")
                page.change("detailLayout", "compact")
                app.check(detail.compactDetails, "compact detail preference saves")
                page.toggleMetric("heat")
                app.check(detail.settings.metrics.indexOf("heat") < 0, "metric visibility saves")
                page.move("gpu", -1)
                app.check(detail.settings.metrics[1] === 'gpu', "metric order saves")
                app.check(Pulse.Metrics.consumers === 2, "two monitors share collector")
                app.check(first.item.fittedCount === 7, "widening restores all GPU readouts: " + first.item.fittedCount + "/" + first.item.availableWidth + "/" + first.item.fullWidth)
                first.item.settings = {layout: "default"}
                app.check(first.item.metricLabel(first.item.metrics.cpu) === "CPU", "default keeps full metric names")
                first.item.settings = {layout: "minimal"}
                app.check(first.item.metricLabel(first.item.metrics.cpu) === "C" && first.item.metricLabel(first.item.metrics['gpu:card1']) === "G2" && !first.item.fittedGraphs, "minimal has short labels and no charts")
                first.item.settings = {layout: "default"}
                app.check(first.item.settings.layout === "default", "automatic fitting preserves preferences")
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
