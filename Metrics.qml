pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "History.js" as History

QtObject {
    id: root
    property var sample: ({memory: {}, disk: {}, gpu: {}, cores: [], palette: {}})
    property var points: []
    property var history: History.empty()
    property double lastUpdate: 0
    property double now: Date.now() / 1000
    property bool stale: true
    property string error: ""
    property int consumers: 0
    property bool initialized: false
    property bool sessionEnabled: false
    property int intervalSeconds: 2
    readonly property bool shouldRun: consumers > 0 && sessionEnabled
    function attach(options) {
        if (!initialized) {
            sessionEnabled = options.autoStart !== false
            initialized = true
        }
        configure(options)
        consumers++
    }
    function detach() { consumers = Math.max(0, consumers - 1) }
    function configure(options) {
        const n = Number(options.intervalSeconds ?? 2)
        const next = [1, 2, 5].indexOf(n) >= 0 ? n : 2
        if (next !== intervalSeconds) {
            intervalSeconds = next
            // Restart is deferred to the watchdog, after Process has actually exited.
            collector.running = false
        }
    }
    function setRunning(value) { sessionEnabled = value }
    function accept(line) {
        if (!shouldRun) return
        try {
            const s = JSON.parse(line)
            if (!History.valid(s)) throw new Error("Invalid sample")
            points = History.append(points, s)
            sample = s
            lastUpdate = Date.now()
            now = lastUpdate / 1000
            history = History.series(points, now)
            stale = false
            error = s.error || ""
        } catch (e) { error = "Invalid telemetry data"; stale = true }
    }
    onShouldRunChanged: {
        if (shouldRun) {
            error = "Waiting for telemetry…"
            collector.running = true
        } else {
            collector.running = false
            points = []
            history = History.empty()
            stale = true
            error = ""
        }
    }
    function percent(value) { return Number.isFinite(value) ? Math.round(value) + "%" : "—" }
    function temp(value) { return Number.isFinite(value) ? Math.round(value) + "°C" : "—" }
    function gib(value) { return Number.isFinite(value) ? (value / 1073741824).toFixed(1) : "—" }
    function rate(value) { return Number.isFinite(value) ? (value / 1048576).toFixed(1) + " MiB/s" : "—" }
    function palette(name, ansi, fallback) { return sample.palette[name] || sample.palette[ansi] || fallback }
    property Process collector: Process {
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("collector.py").toString().replace(/^file:\/\//, "")), "--interval", String(root.intervalSeconds)]
        running: false
        stdout: SplitParser { onRead: data => root.accept(data) }
        onExited: { if (root.shouldRun) { root.stale = true; root.error = "Collector stopped; retrying…" } }
    }
    property Timer watchdog: Timer {
        interval: 1000; running: root.shouldRun; repeat: true
        onTriggered: {
            root.now = Date.now() / 1000
            root.history = History.series(root.points, root.now)
            root.stale = Date.now() - root.lastUpdate > Math.max(7000, root.intervalSeconds * 2500)
            if (!root.collector.running && root.shouldRun) root.collector.running = true
        }
    }
}
