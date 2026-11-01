import Foundation
import CoreGraphics

// MARK: - Prey Modes (专为猫咪视觉与捕猎本能设计的5种模式)

public enum PreyMode: Int, CaseIterable {
    case koiFish = 0     // 🐟 锦鲤游弋 (深海蓝底 + 亮明黄/青白游鱼)
    case mouse = 1       // 🐭 窜动小老鼠 (深暖灰底 + 荧光黄/天蓝高对比度老鼠)
    case ladybug = 2     // 🐞 荧光甲虫 (暗祖母绿底 + 亮黄/电光蓝振翅甲虫)
    case laserDot = 3    // ⚡ 电光激光点 (纯黑深邃底 + 亮青/亮黄高频闪烁光斑)
    case feather = 4     // 🪶 颤动羽毛 (深靛蓝底 + 亮黄/粉青飘动羽毛)

    public var title: String {
        switch self {
        case .koiFish:  return "🐟 锦鲤池塘"
        case .mouse:    return "🐭 窜动小鼠"
        case .ladybug:  return "🐞 荧光甲虫"
        case .laserDot: return "⚡ 电光激光"
        case .feather:  return "🪶 颤动羽毛"
        }
    }

    public var subtitle: String {
        switch self {
        case .koiFish:  return "摆尾游弋 + 水花气泡声"
        case .mouse:    return "急停抖胡须 + 高频吱吱声"
        case .ladybug:  return "振翅停顿 + 咔哒虫鸣声"
        case .laserDot: return "极速折线闪现 + 电光叮当"
        case .feather:  return "飘忽盘旋 + 清脆铃铛声"
        }
    }

    public var baseSpeed: CGFloat {
        switch self {
        case .koiFish:  return 185.0
        case .mouse:    return 290.0
        case .ladybug:  return 220.0
        case .laserDot: return 460.0
        case .feather:  return 240.0
        }
    }

    public var burstMultiplier: CGFloat {
        switch self {
        case .koiFish:  return 2.1
        case .mouse:    return 2.7
        case .ladybug:  return 2.3
        case .laserDot: return 3.1
        case .feather:  return 2.4
        }
    }

    /// 猎物基础碰撞半径（不含猫爪肉垫补偿）
    public var hitRadius: CGFloat {
        switch self {
        case .koiFish:  return 48.0
        case .mouse:    return 46.0
        case .ladybug:  return 42.0
        case .laserDot: return 38.0
        case .feather:  return 50.0
        }
    }
}

// MARK: - Cat-Vision RGB Color Tuple (猫咪双色视觉 450nm蓝紫 + 554nm黄绿 高对比度配色)

public struct RGBAColor: Equatable {
    public let r: CGFloat
    public let g: CGFloat
    public let b: CGFloat
    public let a: CGFloat

    public init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

public struct CatVisionPalette {
    public static func backgroundColor(for mode: PreyMode) -> RGBAColor {
        switch mode {
        case .koiFish:  return RGBAColor(0.03, 0.13, 0.26) // 深海蓝
        case .mouse:    return RGBAColor(0.12, 0.14, 0.18) // 暗石板灰蓝
        case .ladybug:  return RGBAColor(0.05, 0.17, 0.12) // 暗森林绿
        case .laserDot: return RGBAColor(0.03, 0.04, 0.07) // 近纯黑深蓝
        case .feather:  return RGBAColor(0.07, 0.09, 0.20) // 深夜靛蓝
        }
    }

    /// 返回猫咪视网膜最敏感的亮黄、电光青、亮天蓝、炽白配色方案
    public static func preyPrimaryColors(for mode: PreyMode) -> [RGBAColor] {
        switch mode {
        case .koiFish:
            return [
                RGBAColor(1.00, 0.88, 0.15), // 亮金黄锦鲤
                RGBAColor(0.20, 0.92, 1.00), // 电光青锦鲤
                RGBAColor(1.00, 0.96, 0.78)  // 铂金白黄锦鲤
            ]
        case .mouse:
            return [
                RGBAColor(0.98, 0.91, 0.28), // 高对比柠檬黄鼠
                RGBAColor(0.38, 0.86, 1.00), // 亮天蓝鼠
                RGBAColor(0.95, 0.96, 0.98)  // 雪白小仓鼠
            ]
        case .ladybug:
            return [
                RGBAColor(0.95, 0.98, 0.18), // 荧光黄绿甲虫
                RGBAColor(0.15, 0.88, 1.00), // 亮青蓝甲虫
                RGBAColor(1.00, 0.78, 0.12)  // 琥珀金甲虫
            ]
        case .laserDot:
            return [
                RGBAColor(0.18, 0.98, 1.00), // 猫咪高敏电光青激光
                RGBAColor(1.00, 0.95, 0.20), // 高敏亮黄激光
                RGBAColor(1.00, 0.22, 0.45)  // 经典高亮品红激光
            ]
        case .feather:
            return [
                RGBAColor(1.00, 0.90, 0.22), // 明黄羽毛
                RGBAColor(0.25, 0.95, 0.98), // 青蓝羽毛
                RGBAColor(0.92, 0.96, 1.00)  // 亮白羽毛
            ]
        }
    }
}

// MARK: - Peppy-Cat Bio-Motion State Machine (“静-动-急停-探头-突刺”拟真行为状态机)

public enum PreyMotionPhase: Equatable {
    case peeking   // 从屏幕边缘探出半个身子观察（触发猫咪好奇）
    case moving    // 自然蜿蜒游走/爬行
    case pausing   // 突然急停并原地微微颤动胡须/翅膀/尾巴（触发猫咪伏击摇屁股）
    case darting   // 高速折线冲刺逃窜
}

public struct PreyAgentState {
    public let id: Int
    public var mode: PreyMode
    public var colorIndex: Int
    public var position: CGPoint
    public var velocity: CGVector
    public var headingAngle: CGFloat       // 弧度，0 表示朝向 +X
    public var angularVelocity: CGFloat
    public var phase: PreyMotionPhase
    public var phaseTimer: TimeInterval    // 当前阶段剩余时间
    public var totalAge: TimeInterval
    public var wigglePhase: CGFloat        // 用于驱动尾巴/翅膀/胡须摆动
    public var scaleFactor: CGFloat
    public var catchCooldown: TimeInterval
    public var startleCooldown: TimeInterval

    /// 猫爪肉垫触控宽容半径（猫爪面积大且边缘不精准，额外增加 40pt 判定）
    public static let pawForgivenessRadius: CGFloat = 40.0

    public init(
        id: Int,
        mode: PreyMode,
        colorIndex: Int = 0,
        position: CGPoint,
        headingAngle: CGFloat,
        phase: PreyMotionPhase = .peeking,
        phaseTimer: TimeInterval = 0.75,
        scaleFactor: CGFloat = 1.0
    ) {
        self.id = id
        self.mode = mode
        self.colorIndex = colorIndex
        self.position = position
        self.headingAngle = headingAngle
        self.angularVelocity = 0
        let speed = mode.baseSpeed * 0.35
        self.velocity = CGVector(dx: cos(headingAngle) * speed, dy: sin(headingAngle) * speed)
        self.phase = phase
        self.phaseTimer = phaseTimer
        self.totalAge = 0
        self.wigglePhase = CGFloat(id) * 1.7
        self.scaleFactor = scaleFactor
        self.catchCooldown = 0
        self.startleCooldown = 0
    }

    /// 在屏幕四条边缘随机生成探头出生状态
    public static func spawnAtEdge(
        id: Int,
        mode: PreyMode,
        bounds: CGRect,
        randomUnit: () -> CGFloat = { CGFloat.random(in: 0...1) }
    ) -> PreyAgentState {
        let safeW = max(bounds.width, 320)
        let safeH = max(bounds.height, 320)
        let effectiveBounds = CGRect(origin: bounds.origin, size: CGSize(width: safeW, height: safeH))
        let edge = Int(floor(randomUnit() * 4.0)) % 4
        let margin: CGFloat = 18.0
        var pos = CGPoint.zero
        var angle: CGFloat = 0.0

        let t = 0.15 + randomUnit() * 0.70 // 避免出生在死角
        switch edge {
        case 0: // 左边缘 -> 向右探头
            pos = CGPoint(x: effectiveBounds.minX + margin, y: effectiveBounds.minY + safeH * t)
            angle = (randomUnit() - 0.5) * 0.8
        case 1: // 右边缘 -> 向左探头
            pos = CGPoint(x: effectiveBounds.maxX - margin, y: effectiveBounds.minY + safeH * t)
            angle = .pi + (randomUnit() - 0.5) * 0.8
        case 2: // 下边缘 -> 向上探头
            pos = CGPoint(x: effectiveBounds.minX + safeW * t, y: effectiveBounds.minY + margin)
            angle = (.pi / 2.0) + (randomUnit() - 0.5) * 0.8
        default: // 上边缘 -> 向下探头
            pos = CGPoint(x: effectiveBounds.minX + safeW * t, y: effectiveBounds.maxY - margin)
            angle = (-.pi / 2.0) + (randomUnit() - 0.5) * 0.8
        }

        let palettes = CatVisionPalette.preyPrimaryColors(for: mode)
        let colorIdx = Int(floor(randomUnit() * CGFloat(palettes.count))) % max(palettes.count, 1)
        let scale = 0.92 + randomUnit() * 0.24

        return PreyAgentState(
            id: id,
            mode: mode,
            colorIndex: colorIdx,
            position: pos,
            headingAngle: angle,
            phase: .peeking,
            phaseTimer: TimeInterval(0.45 + randomUnit() * 0.55),
            scaleFactor: scale
        )
    }

    /// 推进单帧物理与行为状态机；若刚进入 pausing 阶段则返回 true（供音效层播放轻柔勾引音）
    @discardableResult
    public mutating func step(
        dt: TimeInterval,
        bounds: CGRect,
        randomUnit: () -> CGFloat = { CGFloat.random(in: 0...1) }
    ) -> Bool {
        let clampedDt = min(max(dt, 0.0), 0.1)
        guard clampedDt > 0 else { return false }

        totalAge += clampedDt
        if catchCooldown > 0 {
            catchCooldown = max(0, catchCooldown - clampedDt)
        }
        if startleCooldown > 0 {
            startleCooldown = max(0, startleCooldown - clampedDt)
        }

        phaseTimer -= clampedDt
        var enteredPauseWithTease = false

        if phaseTimer <= 0 {
            enteredPauseWithTease = transitionToNextPhase(bounds: bounds, randomUnit: randomUnit)
        }

        // 根据当前阶段计算速度与蜿蜒转向
        let targetSpeed: CGFloat
        let wiggleRate: CGFloat

        switch phase {
        case .peeking:
            targetSpeed = mode.baseSpeed * 0.22
            wiggleRate = 9.0
        case .moving:
            targetSpeed = mode.baseSpeed
            wiggleRate = 14.0
            // 正弦蜿蜒游动（小鱼和羽毛摆动更柔顺，老鼠和激光更灵动）
            let waveAmp: CGFloat = (mode == .koiFish || mode == .feather) ? 2.4 : 3.2
            headingAngle += sin(CGFloat(totalAge) * 3.8 + CGFloat(id)) * waveAmp * CGFloat(clampedDt) + angularVelocity * CGFloat(clampedDt)
        case .pausing:
            targetSpeed = mode == .koiFish ? mode.baseSpeed * 0.08 : 0.0
            wiggleRate = 22.0 // 原地高频抖动胡须/尾巴/翅膀
        case .darting:
            targetSpeed = mode.baseSpeed * mode.burstMultiplier
            wiggleRate = 28.0
            headingAngle += angularVelocity * CGFloat(clampedDt)
        }

        wigglePhase += wiggleRate * CGFloat(clampedDt)

        // 边界柔和反弹与防卡边引导
        let insetMargin: CGFloat = 54.0
        let safeRect = bounds.insetBy(dx: min(insetMargin, bounds.width * 0.2), dy: min(insetMargin, bounds.height * 0.2))
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        if !safeRect.contains(position) && phase != .peeking {
            let toCenterAngle = atan2(center.y - position.y, center.x - position.x)
            let diff = Self.normalizedAngleDiff(from: headingAngle, to: toCenterAngle)
            let turnStrength: CGFloat = (phase == .darting) ? 9.5 : 6.5
            headingAngle += diff * min(1.0, turnStrength * CGFloat(clampedDt))
        }

        velocity = CGVector(
            dx: cos(headingAngle) * targetSpeed,
            dy: sin(headingAngle) * targetSpeed
        )

        let unclampedX = position.x + velocity.dx * CGFloat(clampedDt)
        let unclampedY = position.y + velocity.dy * CGFloat(clampedDt)

        // 硬性安全夹紧在屏幕可见范围内，并在触壁时立即镜像反射朝向以防贴墙卡死
        let clampPad: CGFloat = 14.0
        let minX = bounds.minX + clampPad
        let maxX = max(minX, bounds.maxX - clampPad)
        let minY = bounds.minY + clampPad
        let maxY = max(minY, bounds.maxY - clampPad)

        position.x = min(max(unclampedX, minX), maxX)
        position.y = min(max(unclampedY, minY), maxY)

        if bounds.width > clampPad * 2 && bounds.height > clampPad * 2 {
            var vx = cos(headingAngle)
            var vy = sin(headingAngle)
            var bounced = false
            if (unclampedX < minX && vx < 0) || (unclampedX > maxX && vx > 0) {
                vx = -vx
                bounced = true
            }
            if (unclampedY < minY && vy < 0) || (unclampedY > maxY && vy > 0) {
                vy = -vy
                bounced = true
            }
            if bounced {
                headingAngle = atan2(vy, vx)
                velocity = CGVector(dx: cos(headingAngle) * targetSpeed, dy: sin(headingAngle) * targetSpeed)
            }
        }

        return enteredPauseWithTease
    }

    private mutating func transitionToNextPhase(
        bounds: CGRect,
        randomUnit: () -> CGFloat
    ) -> Bool {
        let roll = randomUnit()
        let nearEdge = bounds.width > 120 && bounds.height > 120 && !bounds.insetBy(dx: 48, dy: 48).contains(position)

        switch phase {
        case .peeking:
            // 探头结束后迅速窜入屏幕中央区域
            let center = CGPoint(
                x: bounds.midX + (randomUnit() - 0.5) * bounds.width * 0.35,
                y: bounds.midY + (randomUnit() - 0.5) * bounds.height * 0.35
            )
            headingAngle = atan2(center.y - position.y, center.x - position.x)
            angularVelocity = (randomUnit() - 0.5) * 1.6
            phase = .darting
            phaseTimer = TimeInterval(0.45 + randomUnit() * 0.45)
            return false

        case .moving:
            if nearEdge && roll < 0.18 {
                // 游走到屏幕边缘时偶发探头窥视（Peek-a-boo）
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                headingAngle = atan2(center.y - position.y, center.x - position.x) + (randomUnit() - 0.5) * 0.5
                angularVelocity = 0
                phase = .peeking
                phaseTimer = TimeInterval(0.40 + randomUnit() * 0.45)
                return false
            } else if roll < 0.48 {
                // 急停诱捕（Peppy Cat 精髓：动静结合）
                phase = .pausing
                phaseTimer = TimeInterval(0.45 + randomUnit() * 0.85)
                angularVelocity = 0
                return true
            } else {
                // 突然变向冲刺
                phase = .darting
                headingAngle += (randomUnit() - 0.5) * 1.8
                angularVelocity = (randomUnit() - 0.5) * 2.5
                phaseTimer = TimeInterval(0.35 + randomUnit() * 0.50)
                return false
            }

        case .pausing:
            // 停顿后必定触发一次爆发式逃窜或转向游动
            if roll < 0.65 {
                phase = .darting
                headingAngle += (randomUnit() - 0.5) * 2.1
                angularVelocity = (randomUnit() - 0.5) * 2.4
                phaseTimer = TimeInterval(0.38 + randomUnit() * 0.52)
            } else {
                phase = .moving
                headingAngle += (randomUnit() - 0.5) * 1.2
                angularVelocity = (randomUnit() - 0.5) * 1.4
                phaseTimer = TimeInterval(0.90 + randomUnit() * 1.30)
            }
            return false

        case .darting:
            if roll < 0.42 {
                phase = .pausing
                phaseTimer = TimeInterval(0.40 + randomUnit() * 0.70)
                angularVelocity = 0
                return true
            } else {
                phase = .moving
                angularVelocity = (randomUnit() - 0.5) * 1.5
                phaseTimer = TimeInterval(0.85 + randomUnit() * 1.40)
                return false
            }
        }
    }

    /// 当猫爪拍在猎物附近但未直接命中时，触发受惊急速闪避（带冷却与防贴墙保护）
    public mutating func startleAway(
        from pawPoint: CGPoint,
        bounds: CGRect? = nil,
        randomUnit: () -> CGFloat = { CGFloat.random(in: 0...1) }
    ) {
        guard startleCooldown <= 0 else { return }
        let dx = position.x - pawPoint.x
        let dy = position.y - pawPoint.y
        let dist = hypot(dx, dy)
        guard dist < 210.0 else { return }

        var awayAngle: CGFloat
        if dist < 0.001 {
            awayAngle = randomUnit() * 2.0 * .pi
        } else {
            awayAngle = atan2(dy, dx) + (randomUnit() - 0.5) * 0.55
        }

        // 若提供了屏幕边界且逃逸方向会直接撞墙，则朝屏幕中心侧向偏转逃离，避免被猫爪逼入死角卡死
        if let bounds = bounds, bounds.width > 120, bounds.height > 120 {
            let probePoint = CGPoint(
                x: position.x + cos(awayAngle) * 65.0,
                y: position.y + sin(awayAngle) * 65.0
            )
            let safeArea = bounds.insetBy(dx: 28.0, dy: 28.0)
            if !safeArea.contains(probePoint) {
                let toCenter = atan2(bounds.midY - position.y, bounds.midX - position.x)
                let diff = Self.normalizedAngleDiff(from: awayAngle, to: toCenter)
                awayAngle += diff * 0.75
            }
        }

        headingAngle = awayAngle
        angularVelocity = (randomUnit() - 0.5) * 2.0
        phase = .darting
        phaseTimer = TimeInterval(0.40 + randomUnit() * 0.35)
        startleCooldown = 0.14
        let burstSpeed = mode.baseSpeed * mode.burstMultiplier
        velocity = CGVector(dx: cos(headingAngle) * burstSpeed, dy: sin(headingAngle) * burstSpeed)
    }

    /// 判定猫爪触点是否捕获该猎物（综合猎物尺寸缩放与猫爪肉垫宽容半径）
    public func isCaught(byPawAt pawPoint: CGPoint) -> Bool {
        guard catchCooldown <= 0 else { return false }
        let effectiveRadius = mode.hitRadius * scaleFactor + Self.pawForgivenessRadius
        let dx = position.x - pawPoint.x
        let dy = position.y - pawPoint.y
        return (dx * dx + dy * dy) <= (effectiveRadius * effectiveRadius)
    }

    public static func normalizedAngleDiff(from current: CGFloat, to target: CGFloat) -> CGFloat {
        var diff = (target - current).truncatingRemainder(dividingBy: 2.0 * .pi)
        if diff > .pi { diff -= 2.0 * .pi }
        if diff < -.pi { diff += 2.0 * .pi }
        return diff
    }
}

// MARK: - Parental Lock Timer Logic (2.5秒防猫咪误触家长锁状态机)

public struct ParentalLockTracker {
    public let requiredHoldDuration: TimeInterval
    public private(set) var isPressing: Bool = false
    public private(set) var elapsedHoldTime: TimeInterval = 0

    public init(requiredHoldDuration: TimeInterval = 2.5) {
        self.requiredHoldDuration = max(0.5, requiredHoldDuration)
    }

    public var progress: CGFloat {
        guard isPressing else { return 0.0 }
        return CGFloat(min(max(elapsedHoldTime / requiredHoldDuration, 0.0), 1.0))
    }

    public mutating func beginHold() {
        isPressing = true
        elapsedHoldTime = 0
    }

    public mutating func cancelHold() {
        isPressing = false
        elapsedHoldTime = 0
    }

    /// 推进按压计时；如果刚刚达到解锁时长，返回 true 并自动重置按压状态
    public mutating func advance(dt: TimeInterval) -> Bool {
        guard isPressing, dt > 0 else { return false }
        elapsedHoldTime += dt
        if elapsedHoldTime >= requiredHoldDuration {
            isPressing = false
            elapsedHoldTime = 0
            return true
        }
        return false
    }
}

// MARK: - Procedural Cat Audio Waveform Generator (纯代码高频拟声合成算法)

public enum CatSoundEffect {
    case mouseSqueak
    case waterSplash
    case bugChirp
    case laserZap
    case featherBell
    case subtleTease(PreyMode)
}

public struct CatWaveformGenerator {
    public static let defaultSampleRate: Double = 44100.0

    /// 生成单声道 Float32 PCM 采样数组，范围严格限制在 [-0.95, 0.95]
    public static func synthesizeSamples(
        for effect: CatSoundEffect,
        sampleRate: Double = defaultSampleRate
    ) -> [Float] {
        let safeRate = max(8000.0, sampleRate)
        switch effect {
        case .mouseSqueak:
            return generateMouseSqueak(sampleRate: safeRate)
        case .waterSplash:
            return generateWaterSplash(sampleRate: safeRate)
        case .bugChirp:
            return generateBugChirp(sampleRate: safeRate)
        case .laserZap:
            return generateLaserZap(sampleRate: safeRate)
        case .featherBell:
            return generateFeatherBell(sampleRate: safeRate)
        case .subtleTease(let mode):
            return generateSubtleTease(mode: mode, sampleRate: safeRate)
        }
    }

    /// 老鼠双音节高频吱吱声 (2700Hz -> 4300Hz 快速滑音 + 二次谐波)
    private static func generateMouseSqueak(sampleRate: Double) -> [Float] {
        let duration = 0.22
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var phase: Double = 0

        for i in 0..<count {
            let t = Double(i) / sampleRate
            // 分为两段短促吱吱声
            let localT: Double
            let env: Double
            if t < 0.10 {
                localT = t / 0.10
                env = sin(localT * .pi)
            } else if t > 0.115 {
                localT = (t - 0.115) / 0.105
                env = sin(min(1.0, localT) * .pi) * 0.9
            } else {
                localT = 0
                env = 0
            }

            let freq = 2750.0 + 1550.0 * sin(localT * .pi) + 180.0 * sin(t * 95.0)
            phase += 2.0 * .pi * freq / sampleRate
            let sample = (sin(phase) * 0.75 + sin(phase * 2.0) * 0.25) * env * 0.72
            out[i] = clampSample(Float(sample))
        }
        return out
    }

    /// 锦鲤水花与清脆气泡弹出声
    private static func generateWaterSplash(sampleRate: Double) -> [Float] {
        let duration = 0.28
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var phase1: Double = 0
        var phase2: Double = 0
        var noiseState: UInt32 = 0x13579BDF

        for i in 0..<count {
            let t = Double(i) / sampleRate
            // 确定性伪随机白噪声模拟水花
            noiseState = noiseState &* 1664525 &+ 1013904223
            let white = (Double(noiseState & 0xFFFF) / 32768.0) - 1.0
            let splashEnv = exp(-t * 16.0) * sin(min(1.0, t * 80.0) * .pi * 0.5)

            // 两个上浮气泡音 (Bubble Pop)
            var bubble = 0.0
            if t > 0.03 && t < 0.14 {
                let bt = (t - 0.03) / 0.11
                let bFreq = 580.0 + 980.0 * bt * bt
                phase1 += 2.0 * .pi * bFreq / sampleRate
                bubble += sin(phase1) * sin(bt * .pi) * 0.65
            }
            if t > 0.12 && t < 0.25 {
                let bt = (t - 0.12) / 0.13
                let bFreq = 760.0 + 1240.0 * bt * bt
                phase2 += 2.0 * .pi * bFreq / sampleRate
                bubble += sin(phase2) * sin(bt * .pi) * 0.75
            }

            let sample = (white * 0.35 * splashEnv + bubble) * 0.75
            out[i] = clampSample(Float(sample))
        }
        return out
    }

    /// 昆虫振翅与清脆脉冲声
    private static func generateBugChirp(sampleRate: Double) -> [Float] {
        let duration = 0.20
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var carrierPhase: Double = 0

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let env = exp(-t * 12.0) * (0.55 + 0.45 * sin(t * 2.0 * .pi * 48.0))
            let freq = 3400.0 + 650.0 * sin(t * 2.0 * .pi * 36.0)
            carrierPhase += 2.0 * .pi * freq / sampleRate
            let sample = (sin(carrierPhase) * 0.7 + sin(carrierPhase * 1.5) * 0.3) * env * 0.68
            out[i] = clampSample(Float(sample))
        }
        return out
    }

    /// 激光点高频闪现电音与星光音
    private static func generateLaserZap(sampleRate: Double) -> [Float] {
        let duration = 0.19
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var phase: Double = 0
        var chimePhase: Double = 0

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let freq = 4600.0 * pow(0.32, progress) + 600.0 * sin(t * 140.0)
            phase += 2.0 * .pi * freq / sampleRate
            chimePhase += 2.0 * .pi * 5100.0 / sampleRate

            let env = exp(-t * 14.0)
            let sample = (sin(phase) * 0.65 + sin(chimePhase) * 0.35) * env * 0.70
            out[i] = clampSample(Float(sample))
        }
        return out
    }

    /// 羽毛逗猫棒清脆金属铃铛谐波
    private static func generateFeatherBell(sampleRate: Double) -> [Float] {
        let duration = 0.32
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)

        for i in 0..<count {
            let t = Double(i) / sampleRate
            // 双击小铃铛效果
            let t2 = max(0.0, t - 0.085)
            let env1 = exp(-t * 16.0)
            let env2 = t >= 0.085 ? exp(-t2 * 14.0) * 0.85 : 0.0

            let f1 = 3180.0
            let f2 = 4720.0
            let f3 = 6890.0

            let ring1 = (sin(2.0 * .pi * f1 * t) * 0.55 +
                         sin(2.0 * .pi * f2 * t) * 0.30 +
                         sin(2.0 * .pi * f3 * t) * 0.15) * env1

            let ring2 = (sin(2.0 * .pi * (f1 * 1.06) * t2) * 0.55 +
                         sin(2.0 * .pi * (f2 * 1.06) * t2) * 0.30 +
                         sin(2.0 * .pi * (f3 * 1.06) * t2) * 0.15) * env2

            out[i] = clampSample(Float((ring1 + ring2) * 0.65))
        }
        return out
    }

    /// 猎物急停抖动时的轻柔勾引音效（唤醒走神或打盹的猫咪耳朵）
    private static func generateSubtleTease(mode: PreyMode, sampleRate: Double) -> [Float] {
        let duration = 0.09
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var phase: Double = 0

        let baseFreq: Double
        switch mode {
        case .koiFish:  baseFreq = 1150.0
        case .mouse:    baseFreq = 3550.0
        case .ladybug:  baseFreq = 2900.0
        case .laserDot: baseFreq = 4200.0
        case .feather:  baseFreq = 3300.0
        }

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let norm = t / duration
            let env = sin(norm * .pi) * 0.26
            let freq = baseFreq + 420.0 * norm
            phase += 2.0 * .pi * freq / sampleRate
            out[i] = clampSample(Float(sin(phase) * env))
        }
        return out
    }

    private static func clampSample(_ value: Float) -> Float {
        if value > 0.95 { return 0.95 }
        if value < -0.95 { return -0.95 }
        return value
    }
}
