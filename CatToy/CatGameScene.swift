import UIKit
import SpriteKit

public final class CatGameScene: SKScene {

    // MARK: - Game Configuration & State

    public private(set) var currentMode: PreyMode = .koiFish
    public private(set) var targetPreyCount: Int = 2
    public private(set) var isAutoCycleEnabled: Bool = true
    public private(set) var catchScore: Int = 0

    private let autoCycleInterval: TimeInterval = 90.0
    private var autoCycleTimer: TimeInterval = 0.0
    private var lastUpdateTime: TimeInterval = 0.0
    private var nextPreyID: Int = 1
    private var ambientRippleTimer: TimeInterval = 0.0

    // MARK: - Scene Layers

    private let backgroundLayer = SKNode()
    private let rippleLayer = SKNode()
    private let preyLayer = SKNode()
    private let effectsLayer = SKNode()
    private let hudLayer = SKNode()
    private var settingsOverlay: SKNode?

    private var preyNodes: [PreyNode] = []

    // MARK: - HUD & Parental Lock State

    private let scoreBadge = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let modeHintLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let lockButtonNode = SKShapeNode(circleOfRadius: 28)
    private let lockProgressRing = SKShapeNode()
    private let lockIconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lockTracker = ParentalLockTracker(requiredHoldDuration: 2.5)
    private weak var activeLockTouch: UITouch?

    // MARK: - Lifecycle

    public override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        anchorPoint = .zero

        removeAllChildren()
        addChild(backgroundLayer)
        addChild(rippleLayer)
        addChild(preyLayer)
        addChild(effectsLayer)
        addChild(hudLayer)

        setupHUD()
        applyModeTheme()
        syncPreyCount(resetExisting: true)
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 100 && size.height > 100 else { return }
        layoutHUD()
        rebuildBackgroundDecorations()
        let clampPad: CGFloat = 18.0
        for node in preyNodes {
            node.state.position.x = min(max(node.state.position.x, clampPad), max(clampPad, size.width - clampPad))
            node.state.position.y = min(max(node.state.position.y, clampPad), max(clampPad, size.height - clampPad))
            node.syncWithState()
        }
        if settingsOverlay != nil {
            showSettingsOverlay()
        }
    }

    // MARK: - HUD & 2.5s Parental Lock Setup

    private func setupHUD() {
        hudLayer.removeAllChildren()

        scoreBadge.fontSize = 18
        scoreBadge.fontColor = UIColor.white.withAlphaComponent(0.55)
        scoreBadge.horizontalAlignmentMode = .left
        scoreBadge.verticalAlignmentMode = .center
        updateScoreText()
        hudLayer.addChild(scoreBadge)

        modeHintLabel.fontSize = 14
        modeHintLabel.fontColor = UIColor.white.withAlphaComponent(0.40)
        modeHintLabel.horizontalAlignmentMode = .left
        modeHintLabel.verticalAlignmentMode = .center
        hudLayer.addChild(modeHintLabel)

        lockButtonNode.fillColor = UIColor(white: 0.0, alpha: 0.32)
        lockButtonNode.strokeColor = UIColor.white.withAlphaComponent(0.35)
        lockButtonNode.lineWidth = 2.0
        hudLayer.addChild(lockButtonNode)

        lockProgressRing.strokeColor = UIColor(red: 0.20, green: 0.95, blue: 1.00, alpha: 0.95)
        lockProgressRing.fillColor = .clear
        lockProgressRing.lineWidth = 4.5
        lockProgressRing.lineCap = .round
        lockButtonNode.addChild(lockProgressRing)

        lockIconLabel.text = "🔒"
        lockIconLabel.fontSize = 20
        lockIconLabel.horizontalAlignmentMode = .center
        lockIconLabel.verticalAlignmentMode = .center
        lockButtonNode.addChild(lockIconLabel)

        layoutHUD()
    }

    private func layoutHUD() {
        let topY = size.height - 44.0
        scoreBadge.position = CGPoint(x: 26.0, y: topY)
        modeHintLabel.position = CGPoint(x: 26.0, y: topY - 24.0)
        lockButtonNode.position = CGPoint(x: size.width - 46.0, y: topY - 6.0)
    }

    private func updateScoreText() {
        scoreBadge.text = "🐾 捕获 \(catchScore)   |   \(currentMode.title)"
        let autoText = isAutoCycleEnabled ? "自动轮换: 开" : "自动轮换: 关"
        modeHintLabel.text = "\(autoText) · 右上角长按 2.5 秒唤出家长菜单"
    }

    private func updateLockRingVisual() {
        let progress = lockTracker.progress
        guard progress > 0.01 else {
            lockProgressRing.path = nil
            return
        }
        let radius: CGFloat = 31.0
        let startAngle: CGFloat = .pi / 2.0
        let endAngle = startAngle - (.pi * 2.0 * progress)
        let path = UIBezierPath(
            arcCenter: .zero,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        lockProgressRing.path = path.cgPath
    }

    // MARK: - Theme & Ambient Background

    public func switchMode(to newMode: PreyMode) {
        currentMode = newMode
        autoCycleTimer = 0
        applyModeTheme()
        syncPreyCount(resetExisting: true)
        updateScoreText()
    }

    private func applyModeTheme() {
        let bg = CatVisionPalette.backgroundColor(for: currentMode)
        backgroundColor = UIColor(red: bg.r, green: bg.g, blue: bg.b, alpha: bg.a)
        rebuildBackgroundDecorations()
    }

    private func rebuildBackgroundDecorations() {
        backgroundLayer.removeAllChildren()
        guard size.width > 100 && size.height > 100 else { return }

        switch currentMode {
        case .koiFish:
            // 池塘睡莲叶与柔和水纹
            let count = 5
            for i in 0..<count {
                let pad = SKShapeNode(circleOfRadius: CGFloat(34 + (i % 3) * 14))
                pad.fillColor = UIColor(red: 0.08, green: 0.36, blue: 0.28, alpha: 0.38)
                pad.strokeColor = UIColor(red: 0.22, green: 0.65, blue: 0.48, alpha: 0.45)
                pad.lineWidth = 2.0
                let px = size.width * CGFloat(0.15 + Double(i) * 0.18)
                let py = size.height * CGFloat((i % 2 == 0) ? 0.22 : 0.76)
                pad.position = CGPoint(x: px, y: py)
                backgroundLayer.addChild(pad)
            }

        case .ladybug:
            // 草丛暗纹叶片
            for i in 0..<8 {
                let blade = SKShapeNode(ellipseOf: CGSize(width: 90, height: 22))
                blade.fillColor = UIColor(red: 0.09, green: 0.28, blue: 0.18, alpha: 0.42)
                blade.strokeColor = .clear
                blade.zRotation = CGFloat(i) * 0.7
                blade.position = CGPoint(
                    x: size.width * CGFloat(0.12 + Double(i % 4) * 0.25),
                    y: size.height * CGFloat(i < 4 ? 0.20 : 0.80)
                )
                backgroundLayer.addChild(blade)
            }

        default:
            // 微弱高对比参考网格圆点，帮助猫咪判断猎物相对移动速度
            for row in 1...3 {
                for col in 1...4 {
                    let dot = SKShapeNode(circleOfRadius: 3.0)
                    dot.fillColor = UIColor.white.withAlphaComponent(0.07)
                    dot.strokeColor = .clear
                    dot.position = CGPoint(
                        x: size.width * CGFloat(col) / 5.0,
                        y: size.height * CGFloat(row) / 4.0
                    )
                    backgroundLayer.addChild(dot)
                }
            }
        }
    }

    // MARK: - Prey Management

    private func syncPreyCount(resetExisting: Bool) {
        let validBounds = CGRect(origin: .zero, size: CGSize(width: max(size.width, 320), height: max(size.height, 320)))

        if resetExisting {
            for node in preyNodes {
                node.removeFromParent()
            }
            preyNodes.removeAll()
        }

        while preyNodes.count > targetPreyCount {
            if let removed = preyNodes.popLast() {
                removed.removeFromParent()
            }
        }

        while preyNodes.count < targetPreyCount {
            let state = PreyAgentState.spawnAtEdge(id: nextPreyID, mode: currentMode, bounds: validBounds)
            nextPreyID += 1
            let node = PreyNode(state: state)
            preyLayer.addChild(node)
            preyNodes.append(node)
        }
    }

    // MARK: - Frame Update Loop

    public override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(max(currentTime - lastUpdateTime, 0.0), 0.1)
        }
        lastUpdateTime = currentTime

        // 1. 更新家长锁 2.5 秒长按进度
        if lockTracker.isPressing {
            if lockTracker.advance(dt: dt) {
                activeLockTouch = nil
                updateLockRingVisual()
                CatAudioSynth.shared.playCatchSound(for: .feather)
                showSettingsOverlay()
            } else {
                updateLockRingVisual()
            }
        }

        // 如果家长设置面板正在展示，则暂停背后的猎物轮换
        guard settingsOverlay == nil else { return }

        // 2. 自动轮换猎物模式 (90秒)
        if isAutoCycleEnabled {
            autoCycleTimer += dt
            if autoCycleTimer >= autoCycleInterval {
                autoCycleTimer = 0
                let all = PreyMode.allCases
                if let idx = all.firstIndex(of: currentMode) {
                    let nextMode = all[(idx + 1) % all.count]
                    switchMode(to: nextMode)
                }
            }
        }

        // 3. 更新每只猎物的 Peppy-Cat 拟真运动与关节动画
        let sceneBounds = CGRect(origin: .zero, size: size)
        var playedTeaseThisFrame = false

        for node in preyNodes {
            let enteredPause = node.state.step(dt: dt, bounds: sceneBounds)
            node.syncWithState()

            if enteredPause && !playedTeaseThisFrame {
                playedTeaseThisFrame = true
                CatAudioSynth.shared.playTeaseSound(for: currentMode)
            }
        }

        // 4. 锦鲤/激光模式下定期生成环境涟漪或微光轨迹
        ambientRippleTimer += dt
        if ambientRippleTimer >= 0.32 {
            ambientRippleTimer = 0
            if let randomPrey = preyNodes.randomElement() {
                if currentMode == .koiFish && randomPrey.state.phase != .pausing {
                    spawnWaterRipple(at: randomPrey.position, maxRadius: 42, alpha: 0.32)
                } else if currentMode == .laserDot {
                    spawnLaserSpark(at: randomPrey.position)
                }
            }
        }
    }

    // MARK: - Multi-Paw Touch Handling (支持多只猫爪同时拍击与滑动抓捕)

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)

            // 如果设置面板已打开，处理面板点击
            if let overlay = settingsOverlay {
                handleSettingsOverlayTouch(at: touch.location(in: overlay))
                continue
            }

            // 检测是否按在右上角家长锁区域（若已有手指正在长按解锁，忽略第二只猫爪误触以免重置进度）
            if hypot(loc.x - lockButtonNode.position.x, loc.y - lockButtonNode.position.y) <= 40.0 {
                if activeLockTouch == nil || !lockTracker.isPressing {
                    activeLockTouch = touch
                    lockTracker.beginHold()
                    updateLockRingVisual()
                }
                spawnWaterRipple(at: lockButtonNode.position, maxRadius: 36, alpha: 0.4)
                continue
            }

            handlePawStrike(at: loc, isSwipe: false)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)

            if touch == activeLockTouch {
                if hypot(loc.x - lockButtonNode.position.x, loc.y - lockButtonNode.position.y) > 48.0 {
                    lockTracker.cancelHold()
                    activeLockTouch = nil
                    updateLockRingVisual()
                }
                continue
            }

            guard settingsOverlay == nil else { continue }
            handlePawStrike(at: loc, isSwipe: true)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch == activeLockTouch {
            lockTracker.cancelHold()
            activeLockTouch = nil
            updateLockRingVisual()
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch == activeLockTouch {
            lockTracker.cancelHold()
            activeLockTouch = nil
            updateLockRingVisual()
        }
    }

    // MARK: - Paw Strike & Catch Feedback

    private func handlePawStrike(at point: CGPoint, isSwipe: Bool) {
        if !isSwipe {
            spawnWaterRipple(at: point, maxRadius: 56, alpha: 0.48)
        }

        var caughtAny = false
        let validBounds = CGRect(origin: .zero, size: size)

        for node in preyNodes {
            if node.state.isCaught(byPawAt: point) {
                caughtAny = true
                catchScore += 1
                updateScoreText()

                let catchPos = node.position
                CatAudioSynth.shared.playCatchSound(for: currentMode)
                spawnCatchExplosion(at: catchPos, mode: currentMode)

                // 重新从屏幕边缘探头刷新新猎物
                var respawned = PreyAgentState.spawnAtEdge(id: nextPreyID, mode: currentMode, bounds: validBounds)
                respawned.catchCooldown = 0.22
                nextPreyID += 1
                node.state = respawned
                node.rebuildAppearance()
                node.syncWithState()
            } else {
                // 附近未命中的猎物受惊加速逃逸（传入屏幕边界防止被逼入死角贴墙）
                node.state.startleAway(from: point, bounds: validBounds)
            }
        }

        if caughtAny && !isSwipe {
            // 轻微全屏脉冲特效增强爽感
            let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
            flash.fillColor = UIColor.white.withAlphaComponent(0.08)
            flash.strokeColor = .clear
            effectsLayer.addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))
        }
    }

    // MARK: - Procedural Visual Effects (水波纹 / 捕获粒子爆发 / 猫爪印)

    private func spawnWaterRipple(at point: CGPoint, maxRadius: CGFloat, alpha: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.position = point
        ring.fillColor = .clear
        ring.strokeColor = UIColor(red: 0.45, green: 0.92, blue: 1.00, alpha: alpha)
        ring.lineWidth = 2.4
        rippleLayer.addChild(ring)

        let scaleFactor = max(1.5, maxRadius / 10.0)
        let group = SKAction.group([
            .scale(to: scaleFactor, duration: 0.52),
            .fadeOut(withDuration: 0.52)
        ])
        ring.run(.sequence([group, .removeFromParent()]))
    }

    private func spawnLaserSpark(at point: CGPoint) {
        let spark = SKShapeNode(circleOfRadius: 5.0)
        spark.position = point
        spark.fillColor = UIColor(red: 0.25, green: 0.98, blue: 1.00, alpha: 0.70)
        spark.strokeColor = .clear
        rippleLayer.addChild(spark)
        spark.run(.sequence([
            .group([.scale(to: 0.1, duration: 0.28), .fadeOut(withDuration: 0.28)]),
            .removeFromParent()
        ]))
    }

    private func spawnCatchExplosion(at point: CGPoint, mode: PreyMode) {
        // 1. 冲击波双光环
        spawnWaterRipple(at: point, maxRadius: 95, alpha: 0.92)
        spawnWaterRipple(at: point, maxRadius: 64, alpha: 0.75)

        // 2. 12颗高对比四散粒子
        let palette = CatVisionPalette.preyPrimaryColors(for: mode)
        let rgb = palette.first ?? RGBAColor(1.0, 0.92, 0.20)
        let burstColor = UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1.0)

        for i in 0..<12 {
            let angle = (CGFloat(i) / 12.0) * .pi * 2.0 + CGFloat.random(in: -0.2...0.2)
            let dist = CGFloat.random(in: 48...115)
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 5...10))
            p.position = point
            p.fillColor = (i % 2 == 0) ? burstColor : .white
            p.strokeColor = .clear
            effectsLayer.addChild(p)

            let target = CGPoint(x: point.x + cos(angle) * dist, y: point.y + sin(angle) * dist)
            let move = SKAction.move(to: target, duration: 0.38)
            move.timingMode = .easeOut
            p.run(.sequence([
                .group([move, .scale(to: 0.15, duration: 0.38), .fadeOut(withDuration: 0.38)]),
                .removeFromParent()
            ]))
        }

        // 3. 浮动猫爪印标示
        let pawLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        pawLabel.text = "🐾 +1"
        pawLabel.fontSize = 26
        pawLabel.fontColor = UIColor(red: 1.0, green: 0.95, blue: 0.25, alpha: 1.0)
        pawLabel.position = point
        effectsLayer.addChild(pawLabel)

        let floatUp = SKAction.moveBy(x: 0, y: 52, duration: 0.55)
        floatUp.timingMode = .easeOut
        pawLabel.run(.sequence([
            .group([floatUp, .fadeOut(withDuration: 0.55)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Parental Control Settings Overlay

    private func showSettingsOverlay() {
        settingsOverlay?.removeFromParent()

        let overlay = SKNode()
        overlay.zPosition = 500

        let dimmer = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dimmer.fillColor = UIColor(white: 0.0, alpha: 0.76)
        dimmer.strokeColor = .clear
        overlay.addChild(dimmer)

        let panelW: CGFloat = min(560, size.width - 48)
        let panelH: CGFloat = min(500, size.height - 48)
        let panelRect = CGRect(
            x: (size.width - panelW) / 2.0,
            y: (size.height - panelH) / 2.0,
            width: panelW,
            height: panelH
        )

        let card = SKShapeNode(rect: panelRect, cornerRadius: 24)
        card.fillColor = UIColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 0.98)
        card.strokeColor = UIColor(red: 0.25, green: 0.88, blue: 1.00, alpha: 0.7)
        card.lineWidth = 2.5
        overlay.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "🐱 喵喵捕猎 (CatToy) · 家长控制中心"
        title.fontSize = 22
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2.0, y: panelRect.maxY - 42)
        overlay.addChild(title)

        // 5 种猎物模式选择按钮
        let modes = PreyMode.allCases
        let startY = panelRect.maxY - 96
        let rowHeight: CGFloat = 52

        for (index, mode) in modes.enumerated() {
            let btnY = startY - CGFloat(index) * rowHeight
            let btnRect = CGRect(x: panelRect.minX + 28, y: btnY - 20, width: panelW - 56, height: 42)
            let btn = SKShapeNode(rect: btnRect, cornerRadius: 12)
            let isSelected = (mode == currentMode)
            btn.fillColor = isSelected
                ? UIColor(red: 0.14, green: 0.52, blue: 0.86, alpha: 0.95)
                : UIColor(white: 1.0, alpha: 0.09)
            btn.strokeColor = isSelected
                ? UIColor(red: 1.0, green: 0.92, blue: 0.25, alpha: 1.0)
                : UIColor.white.withAlphaComponent(0.22)
            btn.lineWidth = isSelected ? 2.5 : 1.2
            btn.name = "mode_\(mode.rawValue)"
            overlay.addChild(btn)

            let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            lbl.text = "\(mode.title)   —   \(mode.subtitle)"
            lbl.fontSize = 16
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: btnRect.midX, y: btnRect.midY)
            lbl.name = btn.name
            overlay.addChild(lbl)
        }

        // 底部功能开关按钮行（同屏猎物数量 / 音效开关 / 自动轮换）
        let controlsY = panelRect.minY + 102
        let colW = (panelW - 76) / 3.0

        let countText = "猎物数量: \(targetPreyCount) 只"
        addControlOptionButton(
            to: overlay,
            rect: CGRect(x: panelRect.minX + 28, y: controlsY, width: colW, height: 42),
            title: countText,
            name: "toggle_count",
            active: true
        )

        let soundOn = !CatAudioSynth.shared.isMuted
        addControlOptionButton(
            to: overlay,
            rect: CGRect(x: panelRect.minX + 38 + colW, y: controlsY, width: colW, height: 42),
            title: soundOn ? "🔊 拟真音效: 开" : "🔇 拟真音效: 关",
            name: "toggle_sound",
            active: soundOn
        )

        addControlOptionButton(
            to: overlay,
            rect: CGRect(x: panelRect.minX + 48 + colW * 2, y: controlsY, width: colW, height: 42),
            title: isAutoCycleEnabled ? "🔄 90s轮换: 开" : "⏹ 90s轮换: 关",
            name: "toggle_autocycle",
            active: isAutoCycleEnabled
        )

        // 关闭并继续游戏按钮
        let closeRect = CGRect(x: size.width / 2.0 - 120, y: panelRect.minY + 26, width: 240, height: 48)
        let closeBtn = SKShapeNode(rect: closeRect, cornerRadius: 24)
        closeBtn.fillColor = UIColor(red: 0.98, green: 0.82, blue: 0.18, alpha: 1.0)
        closeBtn.strokeColor = .white
        closeBtn.lineWidth = 2.0
        closeBtn.name = "close_settings"
        overlay.addChild(closeBtn)

        let closeLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        closeLbl.text = "返回继续逗猫 🐾"
        closeLbl.fontSize = 18
        closeLbl.fontColor = UIColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 1.0)
        closeLbl.verticalAlignmentMode = .center
        closeLbl.position = CGPoint(x: closeRect.midX, y: closeRect.midY)
        closeLbl.name = "close_settings"
        overlay.addChild(closeLbl)

        hudLayer.addChild(overlay)
        settingsOverlay = overlay
    }

    private func addControlOptionButton(
        to parent: SKNode,
        rect: CGRect,
        title: String,
        name: String,
        active: Bool
    ) {
        let btn = SKShapeNode(rect: rect, cornerRadius: 10)
        btn.fillColor = active
            ? UIColor(red: 0.12, green: 0.44, blue: 0.36, alpha: 0.9)
            : UIColor(white: 1.0, alpha: 0.10)
        btn.strokeColor = UIColor.white.withAlphaComponent(0.35)
        btn.lineWidth = 1.5
        btn.name = name
        parent.addChild(btn)

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = title
        lbl.fontSize = 14
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: rect.midX, y: rect.midY)
        lbl.name = name
        parent.addChild(lbl)
    }

    private func handleSettingsOverlayTouch(at point: CGPoint) {
        guard let overlay = settingsOverlay else { return }
        let touchedNodes = overlay.nodes(at: point)
        guard let namedNode = touchedNodes.first(where: { $0.name != nil }),
              let name = namedNode.name else {
            return
        }

        if name == "close_settings" {
            overlay.removeFromParent()
            settingsOverlay = nil
            updateScoreText()
            return
        }

        if name.hasPrefix("mode_"),
           let raw = Int(name.replacingOccurrences(of: "mode_", with: "")),
           let selectedMode = PreyMode(rawValue: raw) {
            switchMode(to: selectedMode)
            CatAudioSynth.shared.playCatchSound(for: selectedMode)
            showSettingsOverlay()
            return
        }

        if name == "toggle_count" {
            let options = [1, 2, 3, 5]
            if let idx = options.firstIndex(of: targetPreyCount) {
                targetPreyCount = options[(idx + 1) % options.count]
            } else {
                targetPreyCount = 2
            }
            syncPreyCount(resetExisting: false)
            showSettingsOverlay()
            return
        }

        if name == "toggle_sound" {
            CatAudioSynth.shared.isMuted.toggle()
            if !CatAudioSynth.shared.isMuted {
                CatAudioSynth.shared.playCatchSound(for: currentMode)
            }
            showSettingsOverlay()
            return
        }

        if name == "toggle_autocycle" {
            isAutoCycleEnabled.toggle()
            autoCycleTimer = 0
            updateScoreText()
            showSettingsOverlay()
            return
        }
    }
}
