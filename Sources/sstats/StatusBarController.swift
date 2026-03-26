import AppKit

class StatusBarController {
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private var previousCPU: CPUTicks?
    private var previousNet: NetworkBytes?
    private var previousTime: Date?
    private let config: Config

    init(config: Config) {
        self.config = config
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        update()
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: config.updateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.update()
        }
    }

    private func update() {
        let now = Date()

        let currentCPU = readCPUTicks()
        var cpuStr = "C:--"
        if let prev = previousCPU, let curr = currentCPU {
            let pct = cpuUsagePercent(previous: prev, current: curr)
            cpuStr = String(format: "C:%2.0f%%", pct)
        }
        previousCPU = currentCPU

        let memPct = memoryUsagePercent()
        let memStr = String(format: "M:%2.0f%%", memPct)

        let currentNet = readNetworkBytes()
        var netStr = "↓--.-- ↑--.--"
        if let prevNet = previousNet, let prevTime = previousTime {
            let interval = now.timeIntervalSince(prevTime)
            let speed = networkSpeed(previous: prevNet, current: currentNet, interval: interval)
            netStr = String(format: "↓%.1f ↑%.1f", speed.downMbps, speed.upMbps)
        }
        previousNet = currentNet
        previousTime = now

        statusItem.button?.title = "\(cpuStr)  \(memStr)  \(netStr)"
    }
}
