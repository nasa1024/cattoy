import Foundation
import CoreGraphics

private var passedAssertions = 0
private var failedAssertions = 0

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition() {
        passedAssertions += 1
    } else {
        failedAssertions += 1
        print("❌ FAILED [\(file):\(line)]: \(message)")
    }
}

func runAllTests() {
    print("🐾 Running CatToy Automated Test Suite...")

    // 1. 测试全部 5 种猎物模式与猫咪双色视觉调色板
    for mode in PreyMode.allCases {
        assertTrue(!mode.title.isEmpty, "Mode title should not be empty for \(mode)")
        assertTrue(!mode.subtitle.isEmpty, "Mode subtitle should not be empty for \(mode)")
        assertTrue(mode.baseSpeed > 100.0, "Base speed should be positive for \(mode)")
        assertTrue(mode.burstMultiplier > 1.5, "Burst multiplier should > 1.5 for \(mode)")
        assertTrue(mode.hitRadius >= 30.0, "Hit radius should be generous for \(mode)")

        let bg = CatVisionPalette.backgroundColor(for: mode)
        assertTrue((0...1).contains(bg.r) && (0...1).contains(bg.g) && (0...1).contains(bg.b), "Valid BG RGB for \(mode)")

        let colors = CatVisionPalette.preyPrimaryColors(for: mode)
        assertTrue(colors.count >= 3, "At least 3 high-contrast colors for \(mode)")
        for c in colors {
            assertTrue((0...1).contains(c.r) && (0...1).contains(c.g) && (0...1).contains(c.b), "Valid prey RGB")
            // 确保猎物颜色亮度显著高于背景亮度（高对比度保证猫咪看清）
            let preyLuma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
            let bgLuma = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
            assertTrue(preyLuma > bgLuma + 0.25, "Prey color must have high luminance contrast against background for \(mode)")
        }
    }

    // 2. 测试四边探头生成与极端尺寸边界防崩溃
    let ipadBounds = CGRect(x: 0, y: 0, width: 1024, height: 768)
    let edgeSeeds: [CGFloat] = [0.05, 0.30, 0.55, 0.85]
    for (idx, seed) in edgeSeeds.enumerated() {
        var callCount = 0
        let agent = PreyAgentState.spawnAtEdge(id: idx + 1, mode: .mouse, bounds: ipadBounds) {
            callCount += 1
            return callCount == 1 ? seed : 0.5
        }
        assertTrue(agent.phase == .peeking, "Spawned agent should start in .peeking phase")
        assertTrue(ipadBounds.contains(agent.position), "Spawned position must be inside iPad bounds")
        assertTrue(!agent.position.x.isNaN && !agent.position.y.isNaN, "Position must not be NaN")
    }

    // 极端零尺寸窗口测试
    let zeroBounds = CGRect.zero
    var zeroAgent = PreyAgentState.spawnAtEdge(id: 99, mode: .koiFish, bounds: zeroBounds)
    zeroAgent.step(dt: 0.016, bounds: zeroBounds)
    assertTrue(!zeroAgent.position.x.isNaN && !zeroAgent.position.y.isNaN, "Zero bounds step must not produce NaN")

    // 3. 测试 Peppy-Cat “探头 -> 冲刺 -> 急停 -> 游走” 状态机全周期演进与边界防越界
    var simAgent = PreyAgentState.spawnAtEdge(id: 7, mode: .mouse, bounds: ipadBounds) { 0.2 }
    var visitedPhases: Set<String> = ["\(simAgent.phase)"]
    var teaseTriggeredCount = 0

    for stepIdx in 0..<600 {
        let deterministicRand: () -> CGFloat = {
            // 周期性遍历不同随机分支，确保覆盖 pausing / moving / darting
            return CGFloat((stepIdx * 37) % 100) / 100.0
        }
        let enteredTease = simAgent.step(dt: 1.0 / 30.0, bounds: ipadBounds, randomUnit: deterministicRand)
        if enteredTease {
            teaseTriggeredCount += 1
        }
        visitedPhases.insert("\(simAgent.phase)")
        assertTrue(ipadBounds.contains(simAgent.position), "Agent escaped iPad screen bounds at step \(stepIdx): \(simAgent.position)")
    }
    assertTrue(visitedPhases.contains("peeking"), "Should have visited peeking")
    assertTrue(visitedPhases.contains("darting"), "Should have visited darting")
    assertTrue(visitedPhases.contains("pausing"), "Should have visited pausing")
    assertTrue(visitedPhases.contains("moving"), "Should have visited moving")
    assertTrue(teaseTriggeredCount > 0, "Should trigger subtle tease sound on entering pause phase")

    // 测试异常 dt 输入（负数、0、超大卡顿帧）
    let posBeforeZero = simAgent.position
    simAgent.step(dt: 0.0, bounds: ipadBounds)
    assertTrue(simAgent.position == posBeforeZero, "dt=0 should not move prey")
    simAgent.step(dt: -2.0, bounds: ipadBounds)
    assertTrue(simAgent.position == posBeforeZero, "negative dt should not move prey")
    simAgent.step(dt: 15.0, bounds: ipadBounds) // 应被安全钳制到 0.1s
    assertTrue(ipadBounds.contains(simAgent.position), "Huge dt spike must still stay within bounds")

    // 4. 测试猫爪肉垫碰撞宽容半径、冷却保护与受惊闪避
    var targetPrey = PreyAgentState(
        id: 10,
        mode: .koiFish,
        position: CGPoint(x: 500, y: 400),
        headingAngle: 0,
        phase: .moving,
        phaseTimer: 1.0,
        scaleFactor: 1.0
    )
    // 中心直接拍中
    assertTrue(targetPrey.isCaught(byPawAt: CGPoint(x: 500, y: 400)), "Direct center hit must catch prey")
    // 在肉垫宽容边缘内 (48 + 40 = 88pt -> 距离 85pt 应命中)
    assertTrue(targetPrey.isCaught(byPawAt: CGPoint(x: 585, y: 400)), "Edge of forgiving paw radius (85pt <= 88pt) must catch")
    // 超出宽容半径 (距离 92pt > 88pt 应未命中)
    assertTrue(!targetPrey.isCaught(byPawAt: CGPoint(x: 592, y: 400)), "Outside paw radius (92pt > 88pt) must miss")

    // 刚刷新冷却期内不可被连续秒杀
    targetPrey.catchCooldown = 0.20
    assertTrue(!targetPrey.isCaught(byPawAt: CGPoint(x: 500, y: 400)), "Prey in catchCooldown must not be caught")
    targetPrey.step(dt: 0.10, bounds: ipadBounds)
    targetPrey.step(dt: 0.10, bounds: ipadBounds)
    targetPrey.step(dt: 0.05, bounds: ipadBounds)
    assertTrue(targetPrey.catchCooldown == 0, "Cooldown should decay to zero")

    // 猫爪拍在附近 (120pt) 未命中时，猎物应受惊朝反方向进入 .darting
    targetPrey.position = CGPoint(x: 500, y: 400)
    targetPrey.phase = .pausing
    targetPrey.startleAway(from: CGPoint(x: 400, y: 400), randomUnit: { 0.5 })
    assertTrue(targetPrey.phase == .darting, "Prey near paw strike should startle into .darting")
    assertTrue(cos(targetPrey.headingAngle) > 0.7, "Prey should flee in +X direction away from paw at x=400")

    // 5. 测试 2.5 秒防猫咪误触家长锁状态机
    var lock = ParentalLockTracker(requiredHoldDuration: 2.5)
    assertTrue(lock.progress == 0.0, "Initial lock progress must be 0")
    lock.beginHold()
    assertTrue(!lock.advance(dt: 1.0), "1.0s hold must not unlock")
    assertTrue(abs(lock.progress - 0.4) < 0.001, "Progress at 1.0s should be 0.4")
    // 猫爪松开
    lock.cancelHold()
    assertTrue(!lock.isPressing && lock.progress == 0.0, "Canceled hold must reset progress to 0")
    assertTrue(!lock.advance(dt: 3.0), "Advancing while not pressing must never unlock")

    // 人类长按满 2.5 秒
    lock.beginHold()
    assertTrue(!lock.advance(dt: 1.2), "1.2s hold not yet unlocked")
    assertTrue(!lock.advance(dt: 1.2), "2.4s hold not yet unlocked")
    assertTrue(lock.advance(dt: 0.15), "2.55s hold must trigger unlock")
    assertTrue(!lock.isPressing && lock.progress == 0.0, "Unlock should auto-reset pressing state")

    // 6. 测试全部纯代码合成音效波形完整性（无 NaN/Inf、无削波失真、能量充足）
    let allEffects: [CatSoundEffect] = [
        .mouseSqueak,
        .waterSplash,
        .bugChirp,
        .laserZap,
        .featherBell,
        .subtleTease(.koiFish),
        .subtleTease(.mouse),
        .subtleTease(.ladybug),
        .subtleTease(.laserDot),
        .subtleTease(.feather)
    ]

    for effect in allEffects {
        let samples = CatWaveformGenerator.synthesizeSamples(for: effect, sampleRate: 44100.0)
        assertTrue(samples.count >= 3000, "Effect \(effect) must generate sufficient PCM samples")
        var sumSquares: Double = 0
        var maxAbs: Float = 0
        var hasInvalid = false
        for s in samples {
            if s.isNaN || s.isInfinite { hasInvalid = true }
            let a = abs(s)
            if a > maxAbs { maxAbs = a }
            sumSquares += Double(s * s)
        }
        let rms = sqrt(sumSquares / Double(samples.count))
        assertTrue(!hasInvalid, "Effect \(effect) must not contain NaN or Infinite samples")
        assertTrue(maxAbs <= 0.95001, "Effect \(effect) peak amplitude (\(maxAbs)) must be clamped <= 0.95")
        assertTrue(rms > 0.015, "Effect \(effect) must have audible non-zero RMS energy (\(rms))")
    }

    // 7. 测试边界触壁即时镜像反射（防止猎物垂直撞墙时卡在墙壁边缘多帧不动）
    var wallPrey = PreyAgentState(
        id: 21,
        mode: .mouse,
        position: CGPoint(x: 15, y: 400),
        headingAngle: .pi, // 朝左直撞左墙
        phase: .darting,
        phaseTimer: 0.5,
        scaleFactor: 1.0
    )
    wallPrey.step(dt: 1.0 / 60.0, bounds: ipadBounds)
    assertTrue(cos(wallPrey.headingAngle) > 0.0, "Prey hitting left wall must immediately reflect headingAngle inward (+X)")

    // 8. 测试猫爪在屏幕边缘连续滑动 (touchesMoved) 时猎物不会被死死钉在墙边
    var corneredPrey = PreyAgentState(
        id: 22,
        mode: .mouse,
        position: CGPoint(x: 14, y: 400),
        headingAngle: .pi,
        phase: .pausing,
        phaseTimer: 0.5,
        scaleFactor: 1.0
    )
    let startCornerPos = corneredPrey.position
    for _ in 0..<30 {
        // 模拟猫爪在 (100, 400) 处每帧触发 touchesMoved -> startleAway
        corneredPrey.startleAway(from: CGPoint(x: 100, y: 400), bounds: ipadBounds, randomUnit: { 0.5 })
        corneredPrey.step(dt: 1.0 / 60.0, bounds: ipadBounds, randomUnit: { 0.5 })
    }
    let escapedDistance = hypot(corneredPrey.position.x - startCornerPos.x, corneredPrey.position.y - startCornerPos.y)
    assertTrue(escapedDistance > 80.0, "Cornered prey under continuous paw swipe must escape along/away from wall (moved \(escapedDistance)pt)")
    assertTrue(ipadBounds.contains(corneredPrey.position), "Escaped prey must remain inside screen bounds")

    // 9. 测试 CatAudioSynth 多通道混音器初始化与静音状态切换
    let synth = CatAudioSynth.shared
    synth.isMuted = true
    for mode in PreyMode.allCases {
        synth.playCatchSound(for: mode)
        synth.playTeaseSound(for: mode)
    }
    synth.isMuted = false
    for mode in PreyMode.allCases {
        synth.playCatchSound(for: mode)
        synth.playTeaseSound(for: mode)
    }
    assertTrue(!synth.isMuted, "CatAudioSynth should remain functional after polyphonic round-robin scheduling")

    print("✅ Assertions Passed: \(passedAssertions), Failed: \(failedAssertions)")
    if failedAssertions > 0 {
        exit(1)
    }
}

@main
struct CatToyTestRunner {
    static func main() {
        runAllTests()
    }
}
