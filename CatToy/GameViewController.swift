import UIKit
import SpriteKit

public final class GameViewController: UIViewController {

    private var skView: SKView!
    private var gameScene: CatGameScene?

    public override func loadView() {
        let view = SKView(frame: UIScreen.main.bounds)
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        if #available(iOS 15.0, *) {
            view.preferredFramesPerSecond = 120 // 支持 iPad Pro 120Hz ProMotion 极速顺滑
        } else {
            view.preferredFramesPerSecond = 60
        }
        self.skView = view
        self.view = view
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let scene = CatGameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        self.gameScene = scene
        skView.presentScene(scene)
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let scene = gameScene, scene.size != skView.bounds.size {
            scene.size = skView.bounds.size
        }
    }

    // MARK: - 猫咪防误触系统保护 (隐藏状态栏、隐藏底部横条、延迟屏幕边缘系统手势)

    public override var prefersStatusBarHidden: Bool {
        return true
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    public override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
}
