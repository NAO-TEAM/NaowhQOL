local _, ns = ...

local PerfMonitor = {}

function PerfMonitor:Wrap(label, fn)
    return fn
end

function PerfMonitor:Toggle()
end

ns.PerfMonitor = PerfMonitor
