import Darwin
import Foundation

struct CPUTicks {
    var user: UInt64 = 0
    var system: UInt64 = 0
    var idle: UInt64 = 0
    var nice: UInt64 = 0

    var total: UInt64 { user + system + idle + nice }
    var active: UInt64 { user + system + nice }
}

func readCPUTicks() -> CPUTicks? {
    var numCPUs: natural_t = 0
    var cpuInfo: processor_info_array_t?
    var numCPUInfo: mach_msg_type_number_t = 0

    let result = host_processor_info(
        mach_host_self(),
        PROCESSOR_CPU_LOAD_INFO,
        &numCPUs,
        &cpuInfo,
        &numCPUInfo
    )
    guard result == KERN_SUCCESS, let info = cpuInfo else { return nil }

    var ticks = CPUTicks()
    for i in 0..<Int(numCPUs) {
        let offset = Int(CPU_STATE_MAX) * i
        ticks.user += UInt64(info[offset + Int(CPU_STATE_USER)])
        ticks.system += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
        ticks.idle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
        ticks.nice += UInt64(info[offset + Int(CPU_STATE_NICE)])
    }

    let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

    return ticks
}

func cpuUsagePercent(previous: CPUTicks, current: CPUTicks) -> Double {
    let totalDelta = current.total - previous.total
    guard totalDelta > 0 else { return 0 }
    let activeDelta = current.active - previous.active
    return Double(activeDelta) / Double(totalDelta) * 100.0
}

func memoryUsagePercent() -> Double {
    let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(
        MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
    )

    let result = withUnsafeMutablePointer(to: &stats) { ptr in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
            host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
        }
    }
    guard result == KERN_SUCCESS else { return 0 }

    let pageSize = Double(vm_kernel_page_size)
    let active = Double(stats.active_count) * pageSize
    let wired = Double(stats.wire_count) * pageSize
    let compressed = Double(stats.compressor_page_count) * pageSize

    let used = active + wired + compressed
    return used / totalBytes * 100.0
}

struct NetworkBytes {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
}

/// Uses sysctl NET_RT_IFLIST2 to get 64-bit byte counters (if_data64)
/// instead of getifaddrs which only exposes 32-bit counters that wrap at ~4GB.
func readNetworkBytes() -> NetworkBytes {
    var result = NetworkBytes()

    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    var len: size_t = 0
    guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else {
        return result
    }

    var buf = [UInt8](repeating: 0, count: len)
    guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else {
        return result
    }

    var offset = 0
    while offset + MemoryLayout<if_msghdr>.size <= len {
        let hdr = buf.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.advanced(by: offset)
                .withMemoryRebound(to: if_msghdr.self, capacity: 1) { $0.pointee }
        }
        guard hdr.ifm_msglen > 0 else { break }

        if Int32(hdr.ifm_type) == RTM_IFINFO2 {
            buf.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.advanced(by: offset)
                    .withMemoryRebound(to: if_msghdr2.self, capacity: 1) { p in
                        let msg = p.pointee
                        if msg.ifm_flags & Int32(IFF_LOOPBACK) == 0 {
                            result.bytesIn += msg.ifm_data.ifi_ibytes
                            result.bytesOut += msg.ifm_data.ifi_obytes
                        }
                    }
            }
        }

        offset += Int(hdr.ifm_msglen)
    }

    return result
}

struct NetworkSpeed {
    var downMbps: Double
    var upMbps: Double
}

func networkSpeed(previous: NetworkBytes, current: NetworkBytes, interval: Double) -> NetworkSpeed {
    guard interval > 0 else { return NetworkSpeed(downMbps: 0, upMbps: 0) }
    let bytesDown = current.bytesIn >= previous.bytesIn ? current.bytesIn - previous.bytesIn : 0
    let bytesUp = current.bytesOut >= previous.bytesOut ? current.bytesOut - previous.bytesOut : 0
    let mbpsDown = Double(bytesDown) * 8.0 / 1_000_000.0 / interval
    let mbpsUp = Double(bytesUp) * 8.0 / 1_000_000.0 / interval
    return NetworkSpeed(downMbps: mbpsDown, upMbps: mbpsUp)
}
