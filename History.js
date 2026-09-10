.pragma library

const windowSeconds = 60
const maxSamples = 62

function empty() { return {cpu: [], memory: [], gpu: [], cpuTemp: [], gpuTemp: [], hotspot: []} }
function append(points, sample) {
    const now = sample.time
    // A clock adjustment starts a new timeline instead of drawing future samples.
    const previous = points.length && points[points.length - 1].time > now ? [] : points
    return previous.filter(p => p.time >= now - windowSeconds && p.time < now)
        .concat([sample]).slice(-maxSamples)
}
function series(points, now) {
    const result = empty()
    const gpuId = points.length ? points[points.length - 1].gpu.id : undefined
    for (const p of points) {
        if (p.time < now - windowSeconds || p.time > now) continue
        const sameGpu = p.gpu.id === gpuId
        const values = {cpu: p.cpu, memory: p.memory.percent, gpu: sameGpu ? p.gpu.percent : null,
            cpuTemp: p.cpuTemperature, gpuTemp: sameGpu ? p.gpu.temperature : null,
            hotspot: sameGpu ? p.gpu.hotspot : null}
        for (const key in values) result[key].push({time: p.time, value: values[key] ?? null})
    }
    return result
}
function valid(s) {
    return s && Number.isFinite(s.time) && s.time > 0 && s.memory && s.gpu && s.palette && Array.isArray(s.cores)
}
