//
//  GameViewController.swift
//  RogueWave
//
//  Main view controller that presents the SpriteKit game scene
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    // MARK: - Properties

    private var skView: SKView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSKView()
        presentGameScene()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: - Setup

    private func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Performance settings
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60

        // Debug display disabled for cleaner gameplay
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsDrawCount = false

        view.addSubview(skView)
    }

    private func presentGameScene() {
        // Start with main menu instead of game
        let scene = MainMenuScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill

        skView.presentScene(scene)
    }

    // MARK: - Memory Warning

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        // Clear object pools and caches
        ObjectPool.shared.clearAllPools()
    }
}
