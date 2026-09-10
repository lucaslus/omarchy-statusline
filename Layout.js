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

// The shell currently positions its three sections independently. Measure the
// other slots, excluding this widget, so changing our width cannot feed back
// into the budget. Re-evaluates when tray items, clock text or screen size change.
function availableWidth(widget, container, gap) {
    if (!container || !container.width) return Infinity
    let slot = widget.parent
    while (slot && !("region" in slot && "moduleName" in slot)) slot = slot.parent
    if (!slot || (slot.region !== "left" && slot.region !== "right"))
        return container.width * 0.22
    let left = gap, right = container.width - gap, others = 0
    function visit(item) {
        if (!item.visible) return
        if ("region" in item && "moduleName" in item) {
            if (item === slot) return
            if (item.region === slot.region) others += item.width
            else if (item.region === "center" && item.width > 0) {
                const x = item.mapToItem(container, 0, 0).x
                if (slot.region === "right") left = Math.max(left, x + item.width + gap)
                else right = Math.min(right, x - gap)
            } else if (item.region !== "center") {
                // Also reserve the opposite section when no center is present.
                const x = item.mapToItem(container, 0, 0).x
                if (slot.region === "right") left = Math.max(left, x + item.width + gap)
                else right = Math.min(right, x - gap)
            }
            return
        }
        for (const child of item.children || []) visit(child)
    }
    visit(container)
    return Math.max(0, right - left - others)
}
