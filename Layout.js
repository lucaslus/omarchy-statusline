.pragma library
const metricIds = ["cpu", "memory", "gpu", "heat", "disk"]
function normalize(options) {
    const layout = ["overview", "compact", "minimal", "custom"].indexOf(options.layout) >= 0
        ? options.layout : options.compact === true ? "compact" : "overview"
    const order = Array.isArray(options.metrics) ? options.metrics : ["cpu", "memory", "gpu", "heat"]
    const metrics = order.filter((id, i) => metricIds.indexOf(id) >= 0 && order.indexOf(id) === i)
    return {layout: layout, metrics: metrics.length ? metrics : ["cpu"],
        graphs: layout === "custom" ? options.showGraphs !== false : layout !== "minimal",
        stacked: layout === "overview" || (layout === "custom" && options.stackedLabels === true),
        chartWidth: layout === "custom" ? Math.max(20, Math.min(80, Number(options.chartWidth) || 40)) : layout === "overview" ? 48 : 28}
}
