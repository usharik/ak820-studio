import Accelerate
import AK820Kit
import CoreAudio
import Darwin
import Foundation

// MARK: - Settings

enum LiveMode: String, CaseIterable, Codable, Identifiable {
    case music, system
    var id: String { rawValue }
}

enum MusicStyle: String, CaseIterable, Codable, Identifiable {
    case meter, rainbow, gradient, cycle, single
    var id: String { rawValue }

    /// Built-in style of the keyboard when the receiver draws the spectrum itself.
    var dongleCode: UInt8 {
        switch self {
        case .meter: return 1
        case .rainbow: return 2
        case .gradient: return 4
        case .cycle: return 5
        case .single: return 6
        }
    }
}

struct LiveSettings: Codable, Equatable {
    var style: MusicStyle = .meter
    var color = RGB(r: 0, g: 140, b: 255)
    /// Dim color of keys that are not part of a meter (system monitor).
    var background = RGB(r: 0, g: 0, b: 40)
}

// MARK: - Frames

enum LiveRender {
    struct KeyPos { let index: Int; let x: Double; let height: Double }

    /// Key centers: x from 0 (left) to 1 (right), height from 0 (bottom row) to 1 (top row).
    static let keys: [KeyPos] = Layout.keys.map { k in
        KeyPos(index: k.index, x: (k.x + k.w / 2) / Layout.width, height: 1 - (k.y + k.h / 2) / Layout.height)
    }

    static func music(bands: [Float], settings: LiveSettings, time: Double) -> [Int: RGB] {
        var out: [Int: RGB] = [:]
        guard !bands.isEmpty else { return out }
        for k in keys {
            let band = min(bands.count - 1, Int(k.x * Double(bands.count)))
            let level = Double(bands[band])
            let row = min(1, k.height * 1.08)        // the bottom row lights up with little sound
            guard level >= 0.08, row <= level else { out[k.index] = .black; continue }
            switch settings.style {
            case .meter:
                out[k.index] = row < 0.45 ? RGB(r: 0, g: 255, b: 0) : row < 0.75 ? RGB(r: 255, g: 200, b: 0) : RGB(r: 255, g: 0, b: 0)
            case .rainbow: out[k.index] = RGB(hue: k.x * 0.8)
            case .gradient: out[k.index] = RGB(hue: 0.33 * (1 - row))
            case .cycle: out[k.index] = RGB(hue: (time * 0.1 + k.x * 0.3).truncatingRemainder(dividingBy: 1))
            case .single: out[k.index] = settings.color
            }
        }
        return out
    }

    /// Rows lit per band (0…6) for the receiver's built-in spectrum.
    static func heights(_ bands: [Float]) -> [UInt8] {
        let b = bands.count == 21 ? bands : [Float](repeating: 0, count: 21)
        return b.map { $0 < 0.08 ? 0 : UInt8(min(6, ($0 * 6).rounded())) }
    }

    /// F1–F12 show CPU load, the number row shows memory pressure.
    static func system(_ s: SystemMonitor.Sample, settings: LiveSettings) -> [Int: RGB] {
        var out: [Int: RGB] = [:]
        for k in Layout.keys { out[k.index] = settings.background }
        func bar(_ indices: [Int], _ value: Double) {
            let lit = value * Double(indices.count)
            for (i, idx) in indices.enumerated() {
                let pos = Double(i) / Double(max(indices.count - 1, 1))
                let full = RGB(hue: 0.33 * (1 - pos))     // green → red along the row
                let fill = min(max(lit - Double(i), 0), 1)
                out[idx] = fill > 0 ? full.scaled(0.25 + 0.75 * fill) : settings.background
            }
        }
        bar(Array(2...13), s.cpu)
        bar(Array(20...31), s.memory)
        out[1] = RGB(hue: 0.33 * (1 - s.cpu))              // Esc: overall load color
        return out
    }
}

// MARK: - System monitor

final class SystemMonitor {
    struct Sample { let cpu: Double; let memory: Double }

    private var previous: host_cpu_load_info?
    private let host = mach_host_self()

    deinit { mach_port_deallocate(mach_task_self_, host) }

    func sample() -> Sample {
        Sample(cpu: cpuLoad(), memory: memoryUsage())
    }

    private func cpuLoad() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return 0 }
        defer { previous = info }
        guard let p = previous else { return 0 }
        func d(_ i: Int32) -> Double {
            let now = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3][Int(i)]
            let was = [p.cpu_ticks.0, p.cpu_ticks.1, p.cpu_ticks.2, p.cpu_ticks.3][Int(i)]
            return Double(now &- was)
        }
        let busy = d(CPU_STATE_USER) + d(CPU_STATE_SYSTEM) + d(CPU_STATE_NICE)
        let total = busy + d(CPU_STATE_IDLE)
        return total > 0 ? busy / total : 0
    }

    private func memoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return 0 }
        let used = Double(stats.active_count + stats.wire_count + stats.compressor_page_count) * Double(vm_kernel_page_size)
        return min(1, used / Double(ProcessInfo.processInfo.physicalMemory))
    }
}

// MARK: - System audio spectrum

/// Listens to everything the Mac plays (Core Audio process tap, macOS 14.2+) and turns it into
/// 21 log-spaced bands, 0…1, with automatic gain. Ported from ak820-mac's `espectro.swift`.
/// macOS asks for the "System Audio Recording" permission; without it the tap delivers silence.
final class AudioSpectrum {
    static let bandCount = 21
    private static let fftSize = 2048
    private static let log2n = vDSP_Length(11)
    private static let minHz: Float = 45, maxHz: Float = 14000, rangeDB: Float = 48

    private var tap = AudioObjectID(kAudioObjectUnknown)
    private var aggregate = AudioObjectID(kAudioObjectUnknown)
    private var ioProc: AudioDeviceIOProcID?
    private let lock = NSLock()
    private var ring = [Float](repeating: 0, count: AudioSpectrum.fftSize * 4)
    private var writeIndex = 0
    private var sampleRate: Float = 48000

    private let fft = vDSP_create_fftsetup(AudioSpectrum.log2n, FFTRadix(kFFTRadix2))!
    private var window = [Float](repeating: 0, count: AudioSpectrum.fftSize)
    private var peakDB: Float = -40
    private var smooth = [Float](repeating: 0, count: AudioSpectrum.bandCount)
    private var stopped = false

    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    @available(macOS 14.2, *)
    init() throws {
        vDSP_hann_window(&window, vDSP_Length(AudioSpectrum.fftSize), Int32(vDSP_HANN_NORM))
        let fail = { (what: String) in Failure(errorDescription: String(localized: "Can't listen to the system audio: \(what)")) }

        let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        desc.uuid = UUID()
        desc.muteBehavior = .unmuted
        desc.isPrivate = true
        guard AudioHardwareCreateProcessTap(desc, &tap) == noErr else { throw fail("process tap") }

        var output = AudioObjectID(kAudioObjectUnknown)
        guard AudioSpectrum.property(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice, &output) == noErr
        else { cleanup(); throw fail("output device") }
        var uid: CFString = "" as CFString
        guard AudioSpectrum.property(output, kAudioDevicePropertyDeviceUID, &uid) == noErr else { cleanup(); throw fail("device UID") }

        let config: [String: Any] = [
            kAudioAggregateDeviceNameKey: "AK820 Studio",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: uid as String,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: uid as String]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        guard AudioHardwareCreateAggregateDevice(config as CFDictionary, &aggregate) == noErr else { cleanup(); throw fail("aggregate device") }

        var format = AudioStreamBasicDescription()
        guard AudioSpectrum.property(tap, kAudioTapPropertyFormat, &format) == noErr else { cleanup(); throw fail("format") }
        let channels = Int(max(format.mChannelsPerFrame, 1))
        if format.mSampleRate > 0 { sampleRate = Float(format.mSampleRate) }
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0

        let queue = DispatchQueue(label: "ak820.audio", qos: .userInteractive)
        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregate, queue) { [weak self] _, input, _, _, _ in
            let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard let self, let first = list.first, let base = first.mData else { return }
            let total = Int(first.mDataByteSize) / MemoryLayout<Float>.size
            var mono: [Float]
            if interleaved {
                let s = base.assumingMemoryBound(to: Float.self)
                mono = (0..<(total / channels)).map { i in
                    (0..<channels).reduce(Float(0)) { $0 + s[i * channels + $1] } / Float(channels)
                }
            } else {
                mono = [Float](repeating: 0, count: total)
                for buf in list {
                    guard let d = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for i in 0..<total { mono[i] += d[i] / Float(list.count) }
                }
            }
            self.append(mono)
        }
        guard status == noErr, let ioProc else { cleanup(); throw fail("IO proc") }
        guard AudioDeviceStart(aggregate, ioProc) == noErr else { cleanup(); throw fail("start") }
    }

    deinit {
        stop()
        vDSP_destroy_fftsetup(fft)
    }

    /// Only the flag is set under the lock: the HAL waits for a running IO cycle in `AudioDeviceStop`,
    /// and that cycle takes the same lock in `append`.
    func stop() {
        lock.lock()
        let first = !stopped
        stopped = true
        lock.unlock()
        if first { cleanup() }
    }

    private func cleanup() {
        if let ioProc {
            AudioDeviceStop(aggregate, ioProc)
            AudioDeviceDestroyIOProcID(aggregate, ioProc)
            self.ioProc = nil
        }
        if aggregate != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregate); aggregate = kAudioObjectUnknown }
        if tap != kAudioObjectUnknown {
            if #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tap) }
            tap = kAudioObjectUnknown
        }
    }

    private static func property<T>(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T) -> OSStatus {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(obj, &address, 0, nil, &size, &value)
    }

    private func append(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return }
        for s in samples {
            ring[writeIndex] = s
            writeIndex = (writeIndex + 1) % ring.count
        }
    }

    /// Current band levels (0…1): FFT with a Hann window, log bands, fast attack and slow release.
    func bands() -> [Float] {
        let n = AudioSpectrum.fftSize
        lock.lock()
        var samples = (0..<n).map { ring[(writeIndex - n + $0 + ring.count) % ring.count] }
        lock.unlock()

        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(n))
        var re = [Float](repeating: 0, count: n / 2), im = [Float](repeating: 0, count: n / 2)
        var mags = [Float](repeating: 0, count: n / 2)
        re.withUnsafeMutableBufferPointer { r in
            im.withUnsafeMutableBufferPointer { i in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                samples.withUnsafeBytes {
                    vDSP_ctoz($0.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(n / 2))
                }
                vDSP_fft_zrip(fft, &split, 1, AudioSpectrum.log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(n / 2))
            }
        }
        let binHz = sampleRate / Float(n)
        let count = AudioSpectrum.bandCount
        let edges = (0...count).map { i in
            max(1, Int(AudioSpectrum.minHz * pow(AudioSpectrum.maxHz / AudioSpectrum.minHz, Float(i) / Float(count)) / binHz))
        }
        var levels = [Float](repeating: 0, count: count)
        var loudest: Float = -200
        for b in 0..<count {
            let from = min(edges[b], n / 2 - 1)
            let to = min(max(edges[b + 1], from + 1), n / 2)
            levels[b] = 20 * log10((mags[from..<to].max() ?? 0) + 1e-9)
            loudest = max(loudest, levels[b])
        }
        // Automatic gain: the peak follows loud parts at once and decays ~10 dB/s.
        peakDB = max(loudest, peakDB - 0.33)
        if loudest < -100 { smooth = smooth.map { $0 * 0.82 }; return smooth }
        for b in 0..<count {
            let v = max(0, min(1, (levels[b] - (peakDB - AudioSpectrum.rangeDB)) / AudioSpectrum.rangeDB))
            smooth[b] = max(v, smooth[b] * 0.82)
        }
        return smooth
    }
}
