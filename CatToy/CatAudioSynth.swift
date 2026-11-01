import Foundation
import AVFoundation

/// 基于 AVAudioEngine 的零外部依赖实时音效播放器
public final class CatAudioSynth {
    public static let shared = CatAudioSynth()

    public var isMuted: Bool = false

    private let engine = AVAudioEngine()
    private let playerNodes: [AVAudioPlayerNode]
    private var nextPlayerIndex: Int = 0
    private let format: AVAudioFormat
    private var cachedCatchBuffers: [PreyMode: AVAudioPCMBuffer] = [:]
    private var cachedTeaseBuffers: [PreyMode: AVAudioPCMBuffer] = [:]
    private var isEngineRunning: Bool = false

    private init() {
        let sampleRate = CatWaveformGenerator.defaultSampleRate
        self.format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // 创建 4 个并发混音通道，支持多只猫爪同时拍击时音效叠加不中断
        var nodes: [AVAudioPlayerNode] = []
        for _ in 0..<4 {
            nodes.append(AVAudioPlayerNode())
        }
        self.playerNodes = nodes

        setupAudioSessionAndEngine()
        prebuildBuffers()
    }

    private func setupAudioSessionAndEngine() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // 使用 .playback 保证即使 iPad 静音模式开启也能发出逗猫声
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // 忽略模拟器或受限环境下的 AudioSession 错误
        }
        #endif

        let mainMixer = engine.mainMixerNode
        for node in playerNodes {
            engine.attach(node)
            engine.connect(node, to: mainMixer, format: format)
        }

        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else {
            isEngineRunning = true
            return
        }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            isEngineRunning = false
        }
    }

    private func prebuildBuffers() {
        for mode in PreyMode.allCases {
            let effect: CatSoundEffect
            switch mode {
            case .koiFish:  effect = .waterSplash
            case .mouse:    effect = .mouseSqueak
            case .ladybug:  effect = .bugChirp
            case .laserDot: effect = .laserZap
            case .feather:  effect = .featherBell
            }
            if let catchBuffer = makeBuffer(for: effect) {
                cachedCatchBuffers[mode] = catchBuffer
            }
            if let teaseBuffer = makeBuffer(for: .subtleTease(mode)) {
                cachedTeaseBuffers[mode] = teaseBuffer
            }
        }
    }

    private func makeBuffer(for effect: CatSoundEffect) -> AVAudioPCMBuffer? {
        let samples = CatWaveformGenerator.synthesizeSamples(for: effect, sampleRate: format.sampleRate)
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<samples.count {
                channelData[i] = samples[i]
            }
        }
        return buffer
    }

    /// 播放猫爪捕获猎物时的主反馈音效
    public func playCatchSound(for mode: PreyMode) {
        guard !isMuted else { return }
        guard let buffer = cachedCatchBuffers[mode] else { return }
        scheduleBuffer(buffer)
    }

    /// 播放猎物急停抖动时的轻柔勾引声
    public func playTeaseSound(for mode: PreyMode) {
        guard !isMuted else { return }
        guard let buffer = cachedTeaseBuffers[mode] else { return }
        scheduleBuffer(buffer)
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        if !engine.isRunning {
            startEngineIfNeeded()
        }
        guard isEngineRunning, !playerNodes.isEmpty else { return }

        let node = playerNodes[nextPlayerIndex % playerNodes.count]
        nextPlayerIndex = (nextPlayerIndex + 1) % playerNodes.count

        if node.isPlaying {
            node.stop()
        }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        node.play()
    }
}
