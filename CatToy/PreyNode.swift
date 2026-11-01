import UIKit
import SpriteKit

/// 猎物可视化渲染节点（纯矢量多关节动画，无需任何外部图片素材）
public final class PreyNode: SKNode {
    public var state: PreyAgentState

    private let rootVisual = SKNode()
    private let shadowNode = SKShapeNode()
    private let bodyNode = SKShapeNode()
    private let secondaryNode = SKShapeNode() // 斑纹 / 翅膀 / 内核高光
    private let tailNode = SKShapeNode()      // 动态摆动尾巴 / 尾鳍 / 激光拖尾
    private let appendageNode = SKShapeNode() // 胡须 / 触角 / 胸鳍 / 羽枝

    public init(state: PreyAgentState) {
        self.state = state
        super.init()
        setupVisualHierarchy()
        rebuildAppearance()
        syncWithState()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisualHierarchy() {
        addChild(rootVisual)

        shadowNode.fillColor = UIColor(white: 0.0, alpha: 0.28)
        shadowNode.strokeColor = .clear
        shadowNode.position = CGPoint(x: -4, y: -6)
        rootVisual.addChild(shadowNode)

        rootVisual.addChild(tailNode)
        rootVisual.addChild(appendageNode)
        rootVisual.addChild(bodyNode)
        rootVisual.addChild(secondaryNode)
    }

    public func updateModeIfNeeded(_ newMode: PreyMode, colorIndex: Int) {
        if state.mode != newMode || state.colorIndex != colorIndex {
            state.mode = newMode
            state.colorIndex = colorIndex
            rebuildAppearance()
        }
    }

    public func rebuildAppearance() {
        let palette = CatVisionPalette.preyPrimaryColors(for: state.mode)
        let rgb = palette[state.colorIndex % max(1, palette.count)]
        let primaryColor = UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: rgb.a)

        tailNode.removeAllChildren()
        bodyNode.removeAllChildren()
        secondaryNode.removeAllChildren()
        appendageNode.removeAllChildren()

        bodyNode.setScale(1.0)
        bodyNode.zRotation = 0.0
        shadowNode.path = nil
        bodyNode.path = nil
        secondaryNode.path = nil
        tailNode.path = nil
        appendageNode.path = nil
        tailNode.lineCap = .butt
        appendageNode.lineCap = .butt

        switch state.mode {
        case .koiFish:
            buildKoiAppearance(primaryColor: primaryColor)
        case .mouse:
            buildMouseAppearance(primaryColor: primaryColor)
        case .ladybug:
            buildLadybugAppearance(primaryColor: primaryColor)
        case .laserDot:
            buildLaserAppearance(primaryColor: primaryColor)
        case .feather:
            buildFeatherAppearance(primaryColor: primaryColor)
        }

        rootVisual.setScale(state.scaleFactor)
    }

    // MARK: - 5 Mode Procedural Vector Builders

    private func buildKoiAppearance(primaryColor: UIColor) {
        // 鱼身流线型椭圆（朝向 +X）
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 38, y: 0))
        bodyPath.addCurve(to: CGPoint(x: -28, y: 0),
                          control1: CGPoint(x: 22, y: 24),
                          control2: CGPoint(x: -12, y: 18))
        bodyPath.addCurve(to: CGPoint(x: 38, y: 0),
                          control1: CGPoint(x: -12, y: -18),
                          control2: CGPoint(x: 22, y: -24))
        bodyPath.closeSubpath()

        shadowNode.path = bodyPath
        bodyNode.path = bodyPath
        bodyNode.fillColor = primaryColor
        bodyNode.strokeColor = UIColor.white.withAlphaComponent(0.85)
        bodyNode.lineWidth = 2.0

        // 鱼背高对比斑纹与双眼
        let spotPath = CGMutablePath()
        spotPath.addEllipse(in: CGRect(x: -4, y: -9, width: 20, height: 18))
        spotPath.addEllipse(in: CGRect(x: 24, y: 6, width: 6, height: 6))
        spotPath.addEllipse(in: CGRect(x: 24, y: -12, width: 6, height: 6))
        secondaryNode.path = spotPath
        secondaryNode.fillColor = UIColor(red: 0.05, green: 0.18, blue: 0.35, alpha: 0.85)
        secondaryNode.strokeColor = .clear

        // 胸鳍
        let finsPath = CGMutablePath()
        finsPath.move(to: CGPoint(x: 8, y: 14))
        finsPath.addQuadCurve(to: CGPoint(x: -10, y: 30), control: CGPoint(x: 4, y: 28))
        finsPath.addQuadCurve(to: CGPoint(x: -4, y: 12), control: CGPoint(x: -8, y: 18))
        finsPath.move(to: CGPoint(x: 8, y: -14))
        finsPath.addQuadCurve(to: CGPoint(x: -10, y: -30), control: CGPoint(x: 4, y: -28))
        finsPath.addQuadCurve(to: CGPoint(x: -4, y: -12), control: CGPoint(x: -8, y: -18))
        appendageNode.path = finsPath
        appendageNode.fillColor = primaryColor.withAlphaComponent(0.75)
        appendageNode.strokeColor = UIColor.white.withAlphaComponent(0.6)
        appendageNode.lineWidth = 1.5

        tailNode.fillColor = primaryColor.withAlphaComponent(0.9)
        tailNode.strokeColor = UIColor.white.withAlphaComponent(0.75)
        tailNode.lineWidth = 1.8
    }

    private func buildMouseAppearance(primaryColor: UIColor) {
        // 水滴形鼠身（鼻尖在 +X）
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 36, y: 0))
        bodyPath.addCurve(to: CGPoint(x: -26, y: 0),
                          control1: CGPoint(x: 18, y: 24),
                          control2: CGPoint(x: -22, y: 26))
        bodyPath.addCurve(to: CGPoint(x: 36, y: 0),
                          control1: CGPoint(x: -22, y: -26),
                          control2: CGPoint(x: 18, y: -24))
        bodyPath.closeSubpath()

        shadowNode.path = bodyPath
        bodyNode.path = bodyPath
        bodyNode.fillColor = primaryColor
        bodyNode.strokeColor = UIColor.white
        bodyNode.lineWidth = 2.2

        // 大圆耳朵 + 亮色鼻尖 + 黑亮眼睛
        let detailPath = CGMutablePath()
        detailPath.addEllipse(in: CGRect(x: 6, y: 12, width: 16, height: 14))
        detailPath.addEllipse(in: CGRect(x: 6, y: -26, width: 16, height: 14))
        detailPath.addEllipse(in: CGRect(x: 32, y: -4, width: 8, height: 8))
        detailPath.addEllipse(in: CGRect(x: 20, y: 5, width: 5, height: 5))
        detailPath.addEllipse(in: CGRect(x: 20, y: -10, width: 5, height: 5))
        secondaryNode.path = detailPath
        secondaryNode.fillColor = UIColor(red: 0.12, green: 0.55, blue: 0.95, alpha: 0.95)
        secondaryNode.strokeColor = UIColor.white
        secondaryNode.lineWidth = 1.2

        // 6根胡须
        appendageNode.fillColor = .clear
        appendageNode.strokeColor = UIColor.white.withAlphaComponent(0.92)
        appendageNode.lineWidth = 1.8

        // 分节摆动长尾巴
        tailNode.fillColor = .clear
        tailNode.strokeColor = primaryColor
        tailNode.lineWidth = 4.5
        tailNode.lineCap = .round
    }

    private func buildLadybugAppearance(primaryColor: UIColor) {
        let bodyRect = CGRect(x: -24, y: -20, width: 48, height: 40)
        let bodyPath = CGPath(ellipseIn: bodyRect, transform: nil)
        shadowNode.path = bodyPath
        bodyNode.path = bodyPath
        bodyNode.fillColor = primaryColor
        bodyNode.strokeColor = UIColor.white
        bodyNode.lineWidth = 2.2

        // 虫头 + 背部中缝 + 高对比圆斑点
        let spotPath = CGMutablePath()
        spotPath.addEllipse(in: CGRect(x: 16, y: -12, width: 16, height: 24))
        spotPath.move(to: CGPoint(x: -24, y: 0))
        spotPath.addLine(to: CGPoint(x: 18, y: 0))
        spotPath.addEllipse(in: CGRect(x: -6, y: 5, width: 9, height: 9))
        spotPath.addEllipse(in: CGRect(x: -6, y: -14, width: 9, height: 9))
        spotPath.addEllipse(in: CGRect(x: -18, y: 3, width: 7, height: 7))
        spotPath.addEllipse(in: CGRect(x: -18, y: -10, width: 7, height: 7))
        secondaryNode.path = spotPath
        secondaryNode.fillColor = UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 0.92)
        secondaryNode.strokeColor = UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 0.92)
        secondaryNode.lineWidth = 2.0

        // 6条虫腿 + 2根触角
        appendageNode.fillColor = .clear
        appendageNode.strokeColor = primaryColor
        appendageNode.lineWidth = 2.4
        appendageNode.lineCap = .round

        // 振动半透明薄翅
        tailNode.fillColor = UIColor.white.withAlphaComponent(0.35)
        tailNode.strokeColor = UIColor.white.withAlphaComponent(0.8)
        tailNode.lineWidth = 1.5
    }

    private func buildLaserAppearance(primaryColor: UIColor) {
        let outerPath = CGPath(ellipseIn: CGRect(x: -22, y: -22, width: 44, height: 44), transform: nil)
        shadowNode.path = nil
        bodyNode.path = outerPath
        bodyNode.fillColor = primaryColor.withAlphaComponent(0.38)
        bodyNode.strokeColor = primaryColor
        bodyNode.lineWidth = 2.5

        let corePath = CGPath(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20), transform: nil)
        secondaryNode.path = corePath
        secondaryNode.fillColor = .white
        secondaryNode.strokeColor = primaryColor
        secondaryNode.lineWidth = 3.0

        tailNode.fillColor = .clear
        tailNode.strokeColor = primaryColor.withAlphaComponent(0.75)
        tailNode.lineWidth = 6.0
        tailNode.lineCap = .round

        appendageNode.path = nil
    }

    private func buildFeatherAppearance(primaryColor: UIColor) {
        // 羽毛飘逸主体
        let plumePath = CGMutablePath()
        plumePath.move(to: CGPoint(x: 42, y: 0))
        plumePath.addCurve(to: CGPoint(x: -34, y: 0),
                           control1: CGPoint(x: 24, y: 26),
                           control2: CGPoint(x: -14, y: 20))
        plumePath.addCurve(to: CGPoint(x: 42, y: 0),
                           control1: CGPoint(x: -14, y: -20),
                           control2: CGPoint(x: 24, y: -26))
        plumePath.closeSubpath()

        shadowNode.path = plumePath
        bodyNode.path = plumePath
        bodyNode.fillColor = primaryColor
        bodyNode.strokeColor = UIColor.white
        bodyNode.lineWidth = 2.0

        // 羽轴与亮色小铃铛
        let quillPath = CGMutablePath()
        quillPath.move(to: CGPoint(x: -44, y: 0))
        quillPath.addLine(to: CGPoint(x: 38, y: 0))
        quillPath.addEllipse(in: CGRect(x: -42, y: -7, width: 14, height: 14))
        secondaryNode.path = quillPath
        secondaryNode.fillColor = UIColor(red: 0.20, green: 0.95, blue: 1.00, alpha: 1.0)
        secondaryNode.strokeColor = UIColor.white
        secondaryNode.lineWidth = 2.2

        tailNode.fillColor = .clear
        tailNode.strokeColor = primaryColor.withAlphaComponent(0.85)
        tailNode.lineWidth = 2.5

        appendageNode.path = nil
    }

    // MARK: - Frame-by-Frame Procedural Articulation

    public func syncWithState() {
        position = state.position
        zRotation = state.headingAngle

        let w = state.wigglePhase
        let swing = sin(w)

        switch state.mode {
        case .koiFish:
            let tailPath = CGMutablePath()
            let tipY = swing * 18.0
            let midY = cos(w) * 7.0
            tailPath.move(to: CGPoint(x: -24, y: 0))
            tailPath.addQuadCurve(to: CGPoint(x: -54, y: tipY + 14), control: CGPoint(x: -38, y: midY + 10))
            tailPath.addQuadCurve(to: CGPoint(x: -42, y: tipY), control: CGPoint(x: -48, y: tipY + 4))
            tailPath.addQuadCurve(to: CGPoint(x: -54, y: tipY - 14), control: CGPoint(x: -48, y: tipY - 4))
            tailPath.addQuadCurve(to: CGPoint(x: -24, y: 0), control: CGPoint(x: -38, y: midY - 10))
            tailPath.closeSubpath()
            tailNode.path = tailPath

        case .mouse:
            // 动态摇摆长尾巴
            let tailPath = CGMutablePath()
            tailPath.move(to: CGPoint(x: -24, y: 0))
            tailPath.addCurve(
                to: CGPoint(x: -66, y: swing * 20.0),
                control1: CGPoint(x: -38, y: swing * 12.0),
                control2: CGPoint(x: -52, y: -swing * 15.0)
            )
            tailNode.path = tailPath

            // 抖动胡须（尤其在 pausing 阶段高频抽动吸引猫咪）
            let whiskerJitter = swing * 4.5
            let wPath = CGMutablePath()
            for side in [-1.0, 1.0] as [CGFloat] {
                for idx in -1...1 {
                    let spread = CGFloat(idx) * 6.0 + whiskerJitter * side
                    wPath.move(to: CGPoint(x: 28, y: side * 5.0))
                    wPath.addLine(to: CGPoint(x: 34 + CGFloat(idx) * 3.0, y: side * 22.0 + spread))
                }
            }
            appendageNode.path = wPath

        case .ladybug:
            // 6条划动小腿 + 触角
            let legSwing = swing * 5.5
            let lPath = CGMutablePath()
            for side in [-1.0, 1.0] as [CGFloat] {
                // 触角
                lPath.move(to: CGPoint(x: 28, y: side * 5))
                lPath.addQuadCurve(to: CGPoint(x: 42, y: side * 16 + legSwing),
                                   control: CGPoint(x: 36, y: side * 6))
                // 三对步足
                for i in -1...1 {
                    let baseX = CGFloat(i) * 11.0
                    let offset = (i % 2 == 0) ? legSwing : -legSwing
                    lPath.move(to: CGPoint(x: baseX, y: side * 16))
                    lPath.addLine(to: CGPoint(x: baseX + offset, y: side * 29))
                }
            }
            appendageNode.path = lPath

            // 急停或冲刺时扇动半透明薄翅
            if state.phase == .pausing || state.phase == .darting {
                let wingOpen = abs(swing) * 14.0 + 4.0
                let wingPath = CGMutablePath()
                wingPath.addEllipse(in: CGRect(x: -22, y: 4, width: 30, height: wingOpen))
                wingPath.addEllipse(in: CGRect(x: -22, y: -4 - wingOpen, width: 30, height: wingOpen))
                tailNode.path = wingPath
            } else {
                tailNode.path = nil
            }

        case .laserDot:
            let pulse = 1.0 + 0.22 * swing
            bodyNode.setScale(pulse)
            let trailPath = CGMutablePath()
            trailPath.move(to: .zero)
            trailPath.addLine(to: CGPoint(x: -36 - abs(swing) * 18.0, y: swing * 8.0))
            tailNode.path = trailPath

        case .feather:
            let plumeWave = swing * 0.16
            bodyNode.zRotation = plumeWave
            let ribbonPath = CGMutablePath()
            ribbonPath.move(to: CGPoint(x: -38, y: 0))
            ribbonPath.addQuadCurve(to: CGPoint(x: -70, y: swing * 22.0),
                                    control: CGPoint(x: -54, y: -swing * 16.0))
            tailNode.path = ribbonPath
        }
    }
}
