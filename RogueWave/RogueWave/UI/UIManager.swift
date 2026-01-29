//
//  UIManager.swift
//  RogueWave
//
//  Manages all game UI including HUD, upgrade screens, and menus
//

import SpriteKit

// MARK: - UI Manager Delegate

protocol UIManagerDelegate: AnyObject {
    func upgradeSelected(_ upgrade: Upgrade)
    func pauseButtonPressed()
    func restartButtonPressed()
    func mainMenuButtonPressed()
    func abilityButtonPressed(_ ability: UpgradeType)
}

// MARK: - UI Manager Class

class UIManager {

    // MARK: - Properties

    weak var delegate: UIManagerDelegate?
    private weak var scene: SKScene?

    // UI Layers
    private var hudLayer: SKNode!
    private var overlayLayer: SKNode!

    // HUD Elements
    private var healthBar: HealthBar!
    private var xpBar: XPBar!
    private var waveLabel: SKLabelNode!
    private var timerLabel: SKLabelNode!
    private var killCountLabel: SKLabelNode!
    private var levelLabel: SKLabelNode!

    // Ability buttons
    private var abilityButtons: [UpgradeType: AbilityButton] = [:]

    // Overlay screens
    private var upgradeScreen: UpgradeSelectionScreen?
    private var deathScreen: DeathScreen?
    private var pauseScreen: PauseScreen?

    // State
    private(set) var isOverlayActive: Bool = false

    // MARK: - Initialization

    init(scene: SKScene) {
        self.scene = scene
        setupLayers()
        setupHUD()
    }

    // MARK: - Setup

    private func setupLayers() {
        guard let scene = scene,
              let camera = scene.camera else { return }

        // HUD layer (always visible during gameplay) - attached to camera
        hudLayer = SKNode()
        hudLayer.zPosition = GameConfig.ZPosition.ui
        camera.addChild(hudLayer)

        // Overlay layer (for screens that pause gameplay) - attached to camera
        overlayLayer = SKNode()
        overlayLayer.zPosition = GameConfig.ZPosition.overlay
        camera.addChild(overlayLayer)
    }

    private func setupHUD() {
        guard let scene = scene else { return }

        let screenWidth = scene.size.width
        let screenHeight = scene.size.height
        // Large safe area for Dynamic Island (iPhone 14 Pro and later have ~59pt island)
        let safeAreaTop: CGFloat = 60

        // Camera-centered coordinates: (0,0) is center of screen
        // Top-left: (-screenWidth/2, screenHeight/2)
        // Top-right: (screenWidth/2, screenHeight/2)

        // Wave label (top center, in the safe area)
        waveLabel = createLabel(text: "Wave 1", fontSize: 18)
        waveLabel.fontColor = SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        waveLabel.position = CGPoint(x: 0, y: screenHeight / 2 - safeAreaTop)
        hudLayer.addChild(waveLabel)

        // Timer label (below wave)
        timerLabel = createLabel(text: "0:30", fontSize: 14)
        timerLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        timerLabel.position = CGPoint(x: 0, y: screenHeight / 2 - safeAreaTop - 22)
        hudLayer.addChild(timerLabel)

        // Health bar (top left, below wave area)
        healthBar = HealthBar(width: UIConfig.healthBarWidth, height: UIConfig.healthBarHeight)
        healthBar.position = CGPoint(
            x: -screenWidth / 2 + 20 + UIConfig.healthBarWidth / 2,
            y: screenHeight / 2 - safeAreaTop - 55
        )
        hudLayer.addChild(healthBar)

        // XP bar (below health bar)
        xpBar = XPBar(width: UIConfig.xpBarWidth, height: UIConfig.xpBarHeight)
        xpBar.position = CGPoint(
            x: -screenWidth / 2 + 20 + UIConfig.xpBarWidth / 2,
            y: screenHeight / 2 - safeAreaTop - 80
        )
        hudLayer.addChild(xpBar)

        // Level label (next to XP bar)
        levelLabel = createLabel(text: "Lv.1", fontSize: UIConfig.smallFontSize)
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(
            x: -screenWidth / 2 + 20 + UIConfig.xpBarWidth + 10,
            y: screenHeight / 2 - safeAreaTop - 80
        )
        hudLayer.addChild(levelLabel)

        // Kill count (top right)
        killCountLabel = createLabel(text: "Kills: 0", fontSize: 14)
        killCountLabel.horizontalAlignmentMode = .right
        killCountLabel.position = CGPoint(
            x: screenWidth / 2 - 20,
            y: screenHeight / 2 - safeAreaTop - 55
        )
        hudLayer.addChild(killCountLabel)

        // Pause button (top right corner)
        let pauseButton = createButton(text: "II", size: CGSize(width: 40, height: 40))
        pauseButton.position = CGPoint(
            x: screenWidth / 2 - 35,
            y: screenHeight / 2 - safeAreaTop - 95
        )
        pauseButton.name = "pauseButton"
        hudLayer.addChild(pauseButton)
    }

    private func createLabel(text: String, fontSize: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: UIConfig.fontName)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    private func createButton(text: String, size: CGSize) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 8)
        button.fillColor = SKColor.white.withAlphaComponent(0.2)
        button.strokeColor = SKColor.white.withAlphaComponent(0.5)
        button.lineWidth = 2

        let label = SKLabelNode(fontNamed: UIConfig.fontName)
        label.text = text
        label.fontSize = UIConfig.bodyFontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)

        return button
    }

    // MARK: - HUD Updates

    func updateHealth(current: CGFloat, max: CGFloat) {
        healthBar.update(current: current, maxValue: max)
    }

    func updateXP(current: Int, max: Int, level: Int) {
        xpBar.update(current: current, maxValue: max)
        levelLabel.text = "Lv.\(level)"
    }

    func updateWave(_ wave: Int) {
        waveLabel.text = "Wave \(wave)"

        // Wave change animation
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.15)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
        waveLabel.run(SKAction.sequence([scaleUp, scaleDown]))
    }

    func updateTimer(_ timeRemaining: TimeInterval) {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        timerLabel.text = String(format: "%d:%02d", minutes, seconds)

        // Flash when low time
        if timeRemaining <= 10 {
            timerLabel.fontColor = .red
        } else {
            timerLabel.fontColor = .white
        }
    }

    func updateKillCount(_ kills: Int) {
        killCountLabel.text = "Kills: \(kills)"
    }

    // MARK: - Ability Buttons

    func addAbilityButton(for type: UpgradeType) {
        guard let scene = scene, abilityButtons[type] == nil else { return }

        let button = AbilityButton(abilityType: type)
        let buttonIndex = abilityButtons.count
        // Camera-centered coordinates
        let xPos = scene.size.width / 2 - 60
        let yPos: CGFloat = -scene.size.height / 2 + 150 + CGFloat(buttonIndex) * 70

        button.position = CGPoint(x: xPos, y: yPos)
        button.delegate = self
        hudLayer.addChild(button)

        abilityButtons[type] = button
    }

    func updateAbilityCooldown(_ type: UpgradeType, remaining: TimeInterval, total: TimeInterval) {
        abilityButtons[type]?.updateCooldown(remaining: remaining, total: total)
    }

    // MARK: - Overlay Screens

    func showUpgradeSelection(choices: [Upgrade]) {
        guard let scene = scene, !isOverlayActive else { return }

        isOverlayActive = true

        upgradeScreen = UpgradeSelectionScreen(size: scene.size, choices: choices)
        upgradeScreen?.delegate = self
        overlayLayer.addChild(upgradeScreen!)

        // Animate in
        upgradeScreen?.alpha = 0
        upgradeScreen?.run(SKAction.fadeIn(withDuration: 0.3))
    }

    func hideUpgradeSelection() {
        upgradeScreen?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        upgradeScreen = nil
        isOverlayActive = false
    }

    func showDeathScreen(stats: GameStats) {
        guard let scene = scene else { return }

        isOverlayActive = true

        deathScreen = DeathScreen(size: scene.size, stats: stats)
        deathScreen?.delegate = self
        overlayLayer.addChild(deathScreen!)

        // Animate in
        deathScreen?.alpha = 0
        deathScreen?.run(SKAction.fadeIn(withDuration: 0.5))
    }

    func hideDeathScreen() {
        deathScreen?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
        deathScreen = nil
        isOverlayActive = false
    }

    func showPauseScreen() {
        guard let scene = scene, !isOverlayActive else { return }

        isOverlayActive = true

        pauseScreen = PauseScreen(size: scene.size)
        pauseScreen?.delegate = self
        overlayLayer.addChild(pauseScreen!)
    }

    func hidePauseScreen() {
        pauseScreen?.removeFromParent()
        pauseScreen = nil
        isOverlayActive = false
    }

    // MARK: - Touch Handling

    func handleTouch(at location: CGPoint) -> Bool {
        guard let scene = scene else { return false }

        // Convert scene coordinates to camera-relative coordinates
        // The HUD is attached to the camera, so we need camera-relative touch position
        let cameraLocation = CGPoint(
            x: location.x - (scene.camera?.position.x ?? 0),
            y: location.y - (scene.camera?.position.y ?? 0)
        )

        // Check pause button (using camera-relative coordinates)
        if let pauseButton = hudLayer.childNode(withName: "pauseButton"),
           pauseButton.frame.contains(cameraLocation) {
            delegate?.pauseButtonPressed()
            return true
        }

        // Check ability buttons (using camera-relative coordinates with larger hit area)
        for (type, button) in abilityButtons {
            // Use distance check for circular buttons with expanded hit area
            let dx = cameraLocation.x - button.position.x
            let dy = cameraLocation.y - button.position.y
            let distance = sqrt(dx * dx + dy * dy)
            let hitRadius: CGFloat = 35  // Larger hit area for easier tapping while moving
            if distance <= hitRadius {
                delegate?.abilityButtonPressed(type)
                return true
            }
        }

        // Check overlay screens
        if isOverlayActive {
            upgradeScreen?.handleTouch(at: cameraLocation)
            deathScreen?.handleTouch(at: cameraLocation)
            pauseScreen?.handleTouch(at: cameraLocation)
            return true
        }

        return false
    }

    // MARK: - Cleanup

    func reset() {
        hideUpgradeSelection()
        hideDeathScreen()
        hidePauseScreen()

        // Remove ability buttons
        for button in abilityButtons.values {
            button.removeFromParent()
        }
        abilityButtons.removeAll()

        // Reset HUD
        updateHealth(current: 100, max: 100)
        updateXP(current: 0, max: 100, level: 1)
        updateWave(1)
        updateTimer(30)
        updateKillCount(0)
    }
}

// MARK: - AbilityButtonDelegate

extension UIManager: AbilityButtonDelegate {
    func abilityButtonTapped(_ type: UpgradeType) {
        delegate?.abilityButtonPressed(type)
    }
}

// MARK: - UpgradeSelectionDelegate

extension UIManager: UpgradeSelectionDelegate {
    func didSelectUpgrade(_ upgrade: Upgrade) {
        hideUpgradeSelection()
        delegate?.upgradeSelected(upgrade)
    }
}

// MARK: - DeathScreenDelegate

extension UIManager: DeathScreenDelegate {
    func restartTapped() {
        hideDeathScreen()
        delegate?.restartButtonPressed()
    }

    func mainMenuTapped() {
        hideDeathScreen()
        delegate?.mainMenuButtonPressed()
    }
}

// MARK: - PauseScreenDelegate

extension UIManager: PauseScreenDelegate {
    func resumeTapped() {
        hidePauseScreen()
        delegate?.pauseButtonPressed()  // This will call resumeGame() in GameScene
    }

    func quitTapped() {
        hidePauseScreen()
        delegate?.mainMenuButtonPressed()  // Return to main menu
    }
}

// MARK: - Health Bar

class HealthBar: SKNode {

    private var background: SKShapeNode!
    private var foreground: SKShapeNode!
    private var label: SKLabelNode!
    private let width: CGFloat
    private let height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // Background
        background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        background.fillColor = UIConfig.healthBarBackground
        background.strokeColor = SKColor.white.withAlphaComponent(0.3)
        background.lineWidth = 1
        addChild(background)

        // Foreground
        foreground = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        foreground.fillColor = UIConfig.healthBarForeground
        foreground.strokeColor = .clear
        addChild(foreground)

        // Label
        label = SKLabelNode(fontNamed: UIConfig.fontName)
        label.fontSize = UIConfig.smallFontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        addChild(label)
    }

    func update(current: CGFloat, maxValue: CGFloat) {
        let percent = maxValue > 0 ? current / maxValue : 0
        foreground.xScale = max(0.01, percent)
        foreground.position.x = -width / 2 * (1 - percent)

        label.text = "\(Int(current))/\(Int(maxValue))"

        // Color change based on health
        if percent <= 0.25 {
            foreground.fillColor = SKColor.red
        } else if percent <= 0.5 {
            foreground.fillColor = SKColor.orange
        } else {
            foreground.fillColor = UIConfig.healthBarForeground
        }
    }
}

// MARK: - XP Bar

class XPBar: SKNode {

    private var background: SKShapeNode!
    private var foreground: SKShapeNode!
    private let width: CGFloat
    private let height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        background.fillColor = UIConfig.xpBarBackground
        background.strokeColor = .clear
        addChild(background)

        foreground = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        foreground.fillColor = UIConfig.xpBarForeground
        foreground.strokeColor = .clear
        foreground.xScale = 0.01
        addChild(foreground)
    }

    func update(current: Int, maxValue: Int) {
        let percent = maxValue > 0 ? CGFloat(current) / CGFloat(maxValue) : 0
        foreground.xScale = Swift.max(0.01, percent)
        foreground.position.x = -width / 2 * (1 - percent)
    }
}

// MARK: - Ability Button

protocol AbilityButtonDelegate: AnyObject {
    func abilityButtonTapped(_ type: UpgradeType)
}

class AbilityButton: SKNode {

    weak var delegate: AbilityButtonDelegate?

    private let abilityType: UpgradeType
    private var background: SKShapeNode!
    private var innerCircle: SKShapeNode!
    private var cooldownArc: SKShapeNode!
    private var cooldownLabel: SKLabelNode!
    private var iconContainer: SKNode!

    private let size: CGFloat = 55

    init(abilityType: UpgradeType) {
        self.abilityType = abilityType
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // Outer glow ring
        let glowRing = SKShapeNode(circleOfRadius: size / 2 + 3)
        glowRing.fillColor = .clear
        glowRing.strokeColor = abilityType.color
        glowRing.lineWidth = 2
        glowRing.glowWidth = 4
        addChild(glowRing)

        // Background
        background = SKShapeNode(circleOfRadius: size / 2)
        background.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 0.95)
        background.strokeColor = abilityType.color
        background.lineWidth = 3
        addChild(background)

        // Inner colored circle
        innerCircle = SKShapeNode(circleOfRadius: size / 2 - 6)
        innerCircle.fillColor = abilityType.color.withAlphaComponent(0.25)
        innerCircle.strokeColor = .clear
        addChild(innerCircle)

        // Icon container
        iconContainer = SKNode()
        addChild(iconContainer)
        createAbilityIcon()

        // Cooldown arc (pie-style cooldown)
        cooldownArc = SKShapeNode()
        cooldownArc.fillColor = SKColor.black.withAlphaComponent(0.7)
        cooldownArc.strokeColor = .clear
        cooldownArc.zPosition = 5
        cooldownArc.isHidden = true
        addChild(cooldownArc)

        // Cooldown time label
        cooldownLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        cooldownLabel.fontSize = 14
        cooldownLabel.fontColor = .white
        cooldownLabel.verticalAlignmentMode = .center
        cooldownLabel.zPosition = 6
        cooldownLabel.isHidden = true
        addChild(cooldownLabel)

        isUserInteractionEnabled = true
    }

    private func createAbilityIcon() {
        iconContainer.removeAllChildren()
        let iconSize: CGFloat = 18

        switch abilityType {
        case .dash:
            // Arrow/speed lines
            let arrow = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -iconSize * 0.6, y: 0))
            path.addLine(to: CGPoint(x: iconSize * 0.4, y: 0))
            path.addLine(to: CGPoint(x: iconSize * 0.1, y: iconSize * 0.3))
            path.move(to: CGPoint(x: iconSize * 0.4, y: 0))
            path.addLine(to: CGPoint(x: iconSize * 0.1, y: -iconSize * 0.3))
            arrow.path = path
            arrow.strokeColor = .white
            arrow.lineWidth = 3
            arrow.lineCap = .round
            iconContainer.addChild(arrow)

            // Speed lines
            for offset: CGFloat in [-8, -14] {
                let line = SKShapeNode(rectOf: CGSize(width: 6, height: 2))
                line.fillColor = .white
                line.strokeColor = .clear
                line.position = CGPoint(x: offset, y: 0)
                iconContainer.addChild(line)
            }

        case .teleport:
            // Portal/blink effect
            let ring1 = SKShapeNode(circleOfRadius: iconSize * 0.5)
            ring1.fillColor = .clear
            ring1.strokeColor = .white
            ring1.lineWidth = 2
            iconContainer.addChild(ring1)

            let ring2 = SKShapeNode(circleOfRadius: iconSize * 0.25)
            ring2.fillColor = .white
            ring2.strokeColor = .clear
            iconContainer.addChild(ring2)

            // Sparkle effect
            for angle in stride(from: 0, to: 360, by: 90) {
                let sparkle = SKShapeNode(rectOf: CGSize(width: 3, height: 8))
                sparkle.fillColor = .white
                sparkle.strokeColor = .clear
                sparkle.zRotation = CGFloat(angle) * .pi / 180
                sparkle.position = CGPoint(
                    x: cos(CGFloat(angle) * .pi / 180) * iconSize * 0.7,
                    y: sin(CGFloat(angle) * .pi / 180) * iconSize * 0.7
                )
                iconContainer.addChild(sparkle)
            }

        case .shield:
            // Shield shape
            let shieldPath = CGMutablePath()
            shieldPath.move(to: CGPoint(x: 0, y: iconSize * 0.6))
            shieldPath.addCurve(
                to: CGPoint(x: iconSize * 0.5, y: iconSize * 0.2),
                control1: CGPoint(x: iconSize * 0.3, y: iconSize * 0.6),
                control2: CGPoint(x: iconSize * 0.5, y: iconSize * 0.4)
            )
            shieldPath.addLine(to: CGPoint(x: iconSize * 0.5, y: -iconSize * 0.2))
            shieldPath.addCurve(
                to: CGPoint(x: 0, y: -iconSize * 0.6),
                control1: CGPoint(x: iconSize * 0.5, y: -iconSize * 0.4),
                control2: CGPoint(x: iconSize * 0.25, y: -iconSize * 0.6)
            )
            shieldPath.addCurve(
                to: CGPoint(x: -iconSize * 0.5, y: -iconSize * 0.2),
                control1: CGPoint(x: -iconSize * 0.25, y: -iconSize * 0.6),
                control2: CGPoint(x: -iconSize * 0.5, y: -iconSize * 0.4)
            )
            shieldPath.addLine(to: CGPoint(x: -iconSize * 0.5, y: iconSize * 0.2))
            shieldPath.addCurve(
                to: CGPoint(x: 0, y: iconSize * 0.6),
                control1: CGPoint(x: -iconSize * 0.5, y: iconSize * 0.4),
                control2: CGPoint(x: -iconSize * 0.3, y: iconSize * 0.6)
            )
            let shield = SKShapeNode(path: shieldPath)
            shield.fillColor = .white.withAlphaComponent(0.3)
            shield.strokeColor = .white
            shield.lineWidth = 2
            iconContainer.addChild(shield)

        case .aoeBlast:
            // Explosion/burst effect
            let center = SKShapeNode(circleOfRadius: iconSize * 0.2)
            center.fillColor = .white
            center.strokeColor = .clear
            iconContainer.addChild(center)

            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let spike = SKShapeNode(rectOf: CGSize(width: 3, height: iconSize * 0.4))
                spike.fillColor = .white
                spike.strokeColor = .clear
                spike.position = CGPoint(
                    x: cos(angle) * iconSize * 0.4,
                    y: sin(angle) * iconSize * 0.4
                )
                spike.zRotation = angle
                iconContainer.addChild(spike)
            }

            let ring = SKShapeNode(circleOfRadius: iconSize * 0.6)
            ring.fillColor = .clear
            ring.strokeColor = .white
            ring.lineWidth = 2
            iconContainer.addChild(ring)

        default:
            // Default: First letter
            let label = SKLabelNode(fontNamed: UIConfig.fontName)
            label.text = String(abilityType.displayName.prefix(1))
            label.fontSize = 20
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            iconContainer.addChild(label)
        }
    }

    func updateCooldown(remaining: TimeInterval, total: TimeInterval) {
        if remaining > 0 {
            cooldownArc.isHidden = false
            cooldownLabel.isHidden = false

            let percent = CGFloat(remaining / total)

            // Create pie-slice cooldown
            let radius = size / 2 - 2
            let startAngle: CGFloat = .pi / 2
            let endAngle = startAngle + (2 * .pi * percent)

            let path = CGMutablePath()
            path.move(to: .zero)
            path.addArc(center: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()

            cooldownArc.path = path

            // Show remaining time
            cooldownLabel.text = String(format: "%.1f", remaining)

            // Dim the icon
            iconContainer.alpha = 0.3
            innerCircle.alpha = 0.3
        } else {
            cooldownArc.isHidden = true
            cooldownLabel.isHidden = true
            iconContainer.alpha = 1.0
            innerCircle.alpha = 1.0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.abilityButtonTapped(abilityType)

        // Visual feedback
        let pulse = SKAction.sequence([
            SKAction.scale(to: 0.9, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        run(pulse)
    }
}

// MARK: - Upgrade Selection Screen

protocol UpgradeSelectionDelegate: AnyObject {
    func didSelectUpgrade(_ upgrade: Upgrade)
}

class UpgradeSelectionScreen: SKNode {

    weak var delegate: UpgradeSelectionDelegate?

    private let choices: [Upgrade]
    private var cards: [UpgradeCard] = []
    private var cardSize: CGSize = .zero

    init(size: CGSize, choices: [Upgrade]) {
        self.choices = choices
        super.init()
        setup(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(size: CGSize) {
        // Dim background (camera-centered: 0,0 is center)
        let background = SKShapeNode(rectOf: size)
        background.fillColor = SKColor.black.withAlphaComponent(0.85)
        background.strokeColor = .clear
        background.position = CGPoint(x: 0, y: 0)
        addChild(background)

        // Title with glow
        let titleGlow = SKLabelNode(fontNamed: UIConfig.fontName)
        titleGlow.text = "LEVEL UP!"
        titleGlow.fontSize = 28
        titleGlow.fontColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.4)
        titleGlow.position = CGPoint(x: 0, y: size.height / 2 - 80)
        addChild(titleGlow)

        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "LEVEL UP!"
        title.fontSize = 28
        title.fontColor = SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        title.position = CGPoint(x: 0, y: size.height / 2 - 80)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: UIConfig.fontName)
        subtitle.text = "Choose an upgrade"
        subtitle.fontSize = 14
        subtitle.fontColor = SKColor(white: 0.6, alpha: 1.0)
        subtitle.position = CGPoint(x: 0, y: size.height / 2 - 110)
        addChild(subtitle)

        // Create upgrade cards - larger size
        let cardWidth: CGFloat = 110
        let cardHeight: CGFloat = 170
        cardSize = CGSize(width: cardWidth, height: cardHeight)
        let cardSpacing: CGFloat = 15
        let totalWidth = CGFloat(choices.count) * cardWidth + CGFloat(choices.count - 1) * cardSpacing
        let startX = -totalWidth / 2 + cardWidth / 2

        for (index, upgrade) in choices.enumerated() {
            let card = UpgradeCard(upgrade: upgrade, size: cardSize)
            card.position = CGPoint(
                x: startX + CGFloat(index) * (cardWidth + cardSpacing),
                y: -20
            )
            card.name = "card_\(index)"
            addChild(card)
            cards.append(card)

            // Stagger animation
            card.alpha = 0
            card.setScale(0.8)
            card.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1 * Double(index)),
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.2),
                    SKAction.scale(to: 1.0, duration: 0.2)
                ])
            ]))
        }
    }

    func handleTouch(at location: CGPoint) {
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2

        for (index, card) in cards.enumerated() {
            let minX = card.position.x - halfWidth
            let maxX = card.position.x + halfWidth
            let minY = card.position.y - halfHeight
            let maxY = card.position.y + halfHeight

            if location.x >= minX && location.x <= maxX &&
               location.y >= minY && location.y <= maxY {
                delegate?.didSelectUpgrade(choices[index])

                // Visual feedback
                card.run(SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.08),
                    SKAction.scale(to: 1.0, duration: 0.08)
                ]))
                return
            }
        }
    }
}

// MARK: - Upgrade Card

class UpgradeCard: SKNode {

    private let upgrade: Upgrade

    init(upgrade: Upgrade, size: CGSize) {
        self.upgrade = upgrade
        super.init()
        setup(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(size: CGSize) {
        // Card background with gradient effect
        let background = SKShapeNode(rectOf: size, cornerRadius: 12)
        background.fillColor = SKColor(red: 0.08, green: 0.1, blue: 0.15, alpha: 0.95)
        background.strokeColor = upgrade.color
        background.lineWidth = 2
        background.glowWidth = 3
        addChild(background)

        // Top accent bar
        let accentBar = SKShapeNode(rectOf: CGSize(width: size.width - 20, height: 3), cornerRadius: 1.5)
        accentBar.fillColor = upgrade.color
        accentBar.strokeColor = .clear
        accentBar.position = CGPoint(x: 0, y: size.height / 2 - 12)
        addChild(accentBar)

        // Icon container with background
        let iconBg = SKShapeNode(circleOfRadius: 28)
        iconBg.fillColor = upgrade.color.withAlphaComponent(0.2)
        iconBg.strokeColor = upgrade.color
        iconBg.lineWidth = 2
        iconBg.position = CGPoint(x: 0, y: size.height / 2 - 55)
        addChild(iconBg)

        // Create upgrade icon
        let iconContainer = SKNode()
        iconContainer.position = CGPoint(x: 0, y: size.height / 2 - 55)
        addChild(iconContainer)
        createUpgradeIcon(in: iconContainer, type: upgrade.type)

        // Name label - positioned below icon
        let nameLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        nameLabel.text = upgrade.displayName
        nameLabel.fontSize = 13
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: size.height / 2 - 95)
        nameLabel.numberOfLines = 2
        nameLabel.preferredMaxLayoutWidth = size.width - 16
        nameLabel.verticalAlignmentMode = .top
        addChild(nameLabel)

        // Description - positioned at bottom
        let descLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        descLabel.text = upgrade.type.description
        descLabel.fontSize = 9
        descLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        descLabel.position = CGPoint(x: 0, y: -size.height / 2 + 35)
        descLabel.numberOfLines = 3
        descLabel.preferredMaxLayoutWidth = size.width - 16
        descLabel.verticalAlignmentMode = .bottom
        addChild(descLabel)

        // Tap hint
        let tapHint = SKLabelNode(fontNamed: UIConfig.fontName)
        tapHint.text = "TAP"
        tapHint.fontSize = 8
        tapHint.fontColor = upgrade.color
        tapHint.position = CGPoint(x: 0, y: -size.height / 2 + 12)
        addChild(tapHint)
    }

    private func createUpgradeIcon(in container: SKNode, type: UpgradeType) {
        let iconSize: CGFloat = 16

        switch type {
        case .damage:
            // Sword icon
            let blade = SKShapeNode(rectOf: CGSize(width: 6, height: iconSize * 1.5))
            blade.fillColor = .white
            blade.strokeColor = .clear
            blade.position = CGPoint(x: 0, y: 4)
            container.addChild(blade)

            let guard_ = SKShapeNode(rectOf: CGSize(width: iconSize, height: 4))
            guard_.fillColor = .white
            guard_.strokeColor = .clear
            guard_.position = CGPoint(x: 0, y: -6)
            container.addChild(guard_)

        case .attackSpeed:
            // Double arrows
            for offset: CGFloat in [-6, 6] {
                let arrow = createArrowShape(size: iconSize * 0.7)
                arrow.position = CGPoint(x: offset, y: 0)
                container.addChild(arrow)
            }

        case .maxHealth:
            // Heart icon - actual heart shape
            let heartPath = CGMutablePath()
            heartPath.move(to: CGPoint(x: 0, y: -iconSize * 0.5))
            heartPath.addCurve(
                to: CGPoint(x: -iconSize * 0.5, y: iconSize * 0.2),
                control1: CGPoint(x: -iconSize * 0.1, y: -iconSize * 0.5),
                control2: CGPoint(x: -iconSize * 0.5, y: -iconSize * 0.2)
            )
            heartPath.addCurve(
                to: CGPoint(x: 0, y: iconSize * 0.5),
                control1: CGPoint(x: -iconSize * 0.5, y: iconSize * 0.5),
                control2: CGPoint(x: -iconSize * 0.15, y: iconSize * 0.5)
            )
            heartPath.addCurve(
                to: CGPoint(x: iconSize * 0.5, y: iconSize * 0.2),
                control1: CGPoint(x: iconSize * 0.15, y: iconSize * 0.5),
                control2: CGPoint(x: iconSize * 0.5, y: iconSize * 0.5)
            )
            heartPath.addCurve(
                to: CGPoint(x: 0, y: -iconSize * 0.5),
                control1: CGPoint(x: iconSize * 0.5, y: -iconSize * 0.2),
                control2: CGPoint(x: iconSize * 0.1, y: -iconSize * 0.5)
            )
            let heart = SKShapeNode(path: heartPath)
            heart.fillColor = .white
            heart.strokeColor = .clear
            container.addChild(heart)

        case .moveSpeed:
            // Wind/speed swoosh icon
            let swooshPath = CGMutablePath()
            swooshPath.move(to: CGPoint(x: -iconSize * 0.6, y: iconSize * 0.3))
            swooshPath.addQuadCurve(
                to: CGPoint(x: iconSize * 0.6, y: 0),
                control: CGPoint(x: 0, y: iconSize * 0.4)
            )
            swooshPath.addLine(to: CGPoint(x: iconSize * 0.3, y: -iconSize * 0.15))
            swooshPath.addQuadCurve(
                to: CGPoint(x: -iconSize * 0.4, y: iconSize * 0.1),
                control: CGPoint(x: -iconSize * 0.1, y: iconSize * 0.15)
            )
            swooshPath.closeSubpath()
            let swoosh = SKShapeNode(path: swooshPath)
            swoosh.fillColor = .white
            swoosh.strokeColor = .clear
            container.addChild(swoosh)

            // Add speed lines
            for i in 0..<3 {
                let line = SKShapeNode(rectOf: CGSize(width: 10 - CGFloat(i) * 2, height: 2))
                line.fillColor = .white.withAlphaComponent(0.8 - CGFloat(i) * 0.25)
                line.strokeColor = .clear
                line.position = CGPoint(x: -iconSize * 0.5 - CGFloat(i) * 5, y: -iconSize * 0.3 + CGFloat(i) * 3)
                container.addChild(line)
            }

        case .critChance, .critDamage:
            // Lightning bolt
            let boltPath = CGMutablePath()
            boltPath.move(to: CGPoint(x: 4, y: iconSize))
            boltPath.addLine(to: CGPoint(x: -2, y: 2))
            boltPath.addLine(to: CGPoint(x: 4, y: 2))
            boltPath.addLine(to: CGPoint(x: -4, y: -iconSize))
            boltPath.addLine(to: CGPoint(x: 2, y: -2))
            boltPath.addLine(to: CGPoint(x: -4, y: -2))
            boltPath.closeSubpath()
            let bolt = SKShapeNode(path: boltPath)
            bolt.fillColor = .white
            bolt.strokeColor = .clear
            container.addChild(bolt)

        case .dash:
            let arrow = createArrowShape(size: iconSize)
            container.addChild(arrow)
            for offset: CGFloat in [-10, -16] {
                let line = SKShapeNode(rectOf: CGSize(width: 4, height: 2))
                line.fillColor = .white.withAlphaComponent(0.6)
                line.strokeColor = .clear
                line.position = CGPoint(x: offset, y: 0)
                container.addChild(line)
            }

        case .teleport:
            let ring = SKShapeNode(circleOfRadius: iconSize * 0.6)
            ring.fillColor = .clear
            ring.strokeColor = .white
            ring.lineWidth = 2
            container.addChild(ring)
            let center = SKShapeNode(circleOfRadius: iconSize * 0.2)
            center.fillColor = .white
            center.strokeColor = .clear
            container.addChild(center)

        case .shield:
            let shieldPath = CGMutablePath()
            shieldPath.move(to: CGPoint(x: 0, y: iconSize * 0.7))
            shieldPath.addLine(to: CGPoint(x: iconSize * 0.6, y: iconSize * 0.3))
            shieldPath.addLine(to: CGPoint(x: iconSize * 0.6, y: -iconSize * 0.3))
            shieldPath.addLine(to: CGPoint(x: 0, y: -iconSize * 0.7))
            shieldPath.addLine(to: CGPoint(x: -iconSize * 0.6, y: -iconSize * 0.3))
            shieldPath.addLine(to: CGPoint(x: -iconSize * 0.6, y: iconSize * 0.3))
            shieldPath.closeSubpath()
            let shield = SKShapeNode(path: shieldPath)
            shield.fillColor = .white.withAlphaComponent(0.3)
            shield.strokeColor = .white
            shield.lineWidth = 2
            container.addChild(shield)

        case .aoeBlast:
            let center = SKShapeNode(circleOfRadius: 4)
            center.fillColor = .white
            center.strokeColor = .clear
            container.addChild(center)
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let ray = SKShapeNode(rectOf: CGSize(width: 3, height: 8))
                ray.fillColor = .white
                ray.strokeColor = .clear
                ray.position = CGPoint(x: cos(angle) * 10, y: sin(angle) * 10)
                ray.zRotation = angle
                container.addChild(ray)
            }

        case .lifeSteal:
            // Blood drop with heart inside
            let dropPath = CGMutablePath()
            dropPath.move(to: CGPoint(x: 0, y: iconSize * 0.7))
            dropPath.addCurve(
                to: CGPoint(x: iconSize * 0.5, y: -iconSize * 0.1),
                control1: CGPoint(x: 0, y: iconSize * 0.4),
                control2: CGPoint(x: iconSize * 0.5, y: iconSize * 0.2)
            )
            dropPath.addCurve(
                to: CGPoint(x: 0, y: -iconSize * 0.6),
                control1: CGPoint(x: iconSize * 0.5, y: -iconSize * 0.4),
                control2: CGPoint(x: iconSize * 0.2, y: -iconSize * 0.6)
            )
            dropPath.addCurve(
                to: CGPoint(x: -iconSize * 0.5, y: -iconSize * 0.1),
                control1: CGPoint(x: -iconSize * 0.2, y: -iconSize * 0.6),
                control2: CGPoint(x: -iconSize * 0.5, y: -iconSize * 0.4)
            )
            dropPath.addCurve(
                to: CGPoint(x: 0, y: iconSize * 0.7),
                control1: CGPoint(x: -iconSize * 0.5, y: iconSize * 0.2),
                control2: CGPoint(x: 0, y: iconSize * 0.4)
            )
            let drop = SKShapeNode(path: dropPath)
            drop.fillColor = .white
            drop.strokeColor = .clear
            container.addChild(drop)

            // Small heart inside the drop
            let miniHeart = SKShapeNode(circleOfRadius: 4)
            miniHeart.fillColor = upgrade.color
            miniHeart.strokeColor = .clear
            miniHeart.position = CGPoint(x: 0, y: -iconSize * 0.15)
            container.addChild(miniHeart)

        case .armor:
            // Shield/armor icon
            let shieldPath = CGMutablePath()
            shieldPath.move(to: CGPoint(x: 0, y: iconSize * 0.7))
            shieldPath.addLine(to: CGPoint(x: iconSize * 0.6, y: iconSize * 0.4))
            shieldPath.addLine(to: CGPoint(x: iconSize * 0.6, y: -iconSize * 0.1))
            shieldPath.addCurve(
                to: CGPoint(x: 0, y: -iconSize * 0.7),
                control1: CGPoint(x: iconSize * 0.6, y: -iconSize * 0.4),
                control2: CGPoint(x: iconSize * 0.3, y: -iconSize * 0.65)
            )
            shieldPath.addCurve(
                to: CGPoint(x: -iconSize * 0.6, y: -iconSize * 0.1),
                control1: CGPoint(x: -iconSize * 0.3, y: -iconSize * 0.65),
                control2: CGPoint(x: -iconSize * 0.6, y: -iconSize * 0.4)
            )
            shieldPath.addLine(to: CGPoint(x: -iconSize * 0.6, y: iconSize * 0.4))
            shieldPath.closeSubpath()
            let shield = SKShapeNode(path: shieldPath)
            shield.fillColor = .white.withAlphaComponent(0.3)
            shield.strokeColor = .white
            shield.lineWidth = 2
            container.addChild(shield)

            // Add cross pattern on shield
            let crossH = SKShapeNode(rectOf: CGSize(width: iconSize * 0.6, height: 3))
            crossH.fillColor = .white
            crossH.strokeColor = .clear
            crossH.position = CGPoint(x: 0, y: 0)
            container.addChild(crossH)
            let crossV = SKShapeNode(rectOf: CGSize(width: 3, height: iconSize * 0.6))
            crossV.fillColor = .white
            crossV.strokeColor = .clear
            crossV.position = CGPoint(x: 0, y: 0)
            container.addChild(crossV)

        case .multishot:
            // Three arrows spreading out
            let angles: [CGFloat] = [-0.4, 0, 0.4]
            for angle in angles {
                let arrowPath = CGMutablePath()
                arrowPath.move(to: CGPoint(x: iconSize * 0.5, y: 0))
                arrowPath.addLine(to: CGPoint(x: iconSize * 0.2, y: 3))
                arrowPath.addLine(to: CGPoint(x: iconSize * 0.2, y: 1))
                arrowPath.addLine(to: CGPoint(x: -iconSize * 0.5, y: 1))
                arrowPath.addLine(to: CGPoint(x: -iconSize * 0.5, y: -1))
                arrowPath.addLine(to: CGPoint(x: iconSize * 0.2, y: -1))
                arrowPath.addLine(to: CGPoint(x: iconSize * 0.2, y: -3))
                arrowPath.closeSubpath()
                let arrow = SKShapeNode(path: arrowPath)
                arrow.fillColor = .white
                arrow.strokeColor = .clear
                arrow.zRotation = angle
                container.addChild(arrow)
            }

        default:
            // Default: first letter
            let label = SKLabelNode(fontNamed: UIConfig.fontName)
            label.text = String(type.displayName.prefix(1))
            label.fontSize = 20
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            container.addChild(label)
        }
    }

    private func createArrowShape(size: CGFloat) -> SKNode {
        let container = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: size * 0.8, height: 4))
        shaft.fillColor = .white
        shaft.strokeColor = .clear
        container.addChild(shaft)

        let headPath = CGMutablePath()
        headPath.move(to: CGPoint(x: size * 0.4, y: 0))
        headPath.addLine(to: CGPoint(x: size * 0.1, y: size * 0.4))
        headPath.addLine(to: CGPoint(x: size * 0.1, y: -size * 0.4))
        headPath.closeSubpath()
        let head = SKShapeNode(path: headPath)
        head.fillColor = .white
        head.strokeColor = .clear
        container.addChild(head)

        return container
    }
}

// MARK: - Death Screen

protocol DeathScreenDelegate: AnyObject {
    func restartTapped()
    func mainMenuTapped()
}

struct GameStats {
    var wavesCompleted: Int = 0
    var enemiesKilled: Int = 0
    var damageDealt: Int = 0
    var timeSurvived: TimeInterval = 0
    var upgradesCollected: Int = 0
}

class DeathScreen: SKNode {

    weak var delegate: DeathScreenDelegate?

    private var restartButton: SKShapeNode!
    private var menuButton: SKShapeNode!

    init(size: CGSize, stats: GameStats) {
        super.init()
        setup(size: size, stats: stats)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(size: CGSize, stats: GameStats) {
        // Background (camera-centered: 0,0 is center)
        let background = SKShapeNode(rectOf: size)
        background.fillColor = SKColor.black.withAlphaComponent(0.9)
        background.strokeColor = .clear
        background.position = CGPoint(x: 0, y: 0)
        addChild(background)

        // Game Over title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "GAME OVER"
        title.fontSize = 40
        title.fontColor = SKColor.red
        title.position = CGPoint(x: 0, y: size.height / 2 - 120)
        addChild(title)

        // Stats
        let statsY: CGFloat = 50
        let statsSpacing: CGFloat = 30

        let statsTexts = [
            "Waves: \(stats.wavesCompleted)",
            "Kills: \(stats.enemiesKilled)",
            "Time: \(formatTime(stats.timeSurvived))",
            "Upgrades: \(stats.upgradesCollected)"
        ]

        for (index, text) in statsTexts.enumerated() {
            let label = SKLabelNode(fontNamed: UIConfig.fontName)
            label.text = text
            label.fontSize = UIConfig.bodyFontSize
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: statsY - CGFloat(index) * statsSpacing)
            addChild(label)
        }

        // Restart button
        restartButton = createButton(text: "Play Again", width: 180, height: 50)
        restartButton.position = CGPoint(x: 0, y: -size.height / 2 + 180)
        restartButton.name = "restartButton"
        addChild(restartButton)

        // Menu button
        menuButton = createButton(text: "Main Menu", width: 180, height: 50)
        menuButton.position = CGPoint(x: 0, y: -size.height / 2 + 110)
        menuButton.name = "menuButton"
        addChild(menuButton)
    }

    private func createButton(text: String, width: CGFloat, height: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        button.fillColor = SKColor.white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.lineWidth = 2

        let label = SKLabelNode(fontNamed: UIConfig.fontName)
        label.text = text
        label.fontSize = UIConfig.bodyFontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)

        return button
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func handleTouch(at location: CGPoint) {
        if restartButton.contains(location) {
            delegate?.restartTapped()
        } else if menuButton.contains(location) {
            delegate?.mainMenuTapped()
        }
    }
}

// MARK: - Pause Screen

protocol PauseScreenDelegate: AnyObject {
    func resumeTapped()
    func quitTapped()
}

class PauseScreen: SKNode {

    weak var delegate: PauseScreenDelegate?

    private var resumeButton: SKShapeNode!
    private var quitButton: SKShapeNode!

    init(size: CGSize) {
        super.init()
        setup(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(size: CGSize) {
        // Background (camera-centered: 0,0 is center)
        let background = SKShapeNode(rectOf: size)
        background.fillColor = SKColor.black.withAlphaComponent(0.8)
        background.strokeColor = .clear
        background.position = CGPoint(x: 0, y: 0)
        addChild(background)

        // Title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "PAUSED"
        title.fontSize = UIConfig.titleFontSize
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 80)
        addChild(title)

        // Resume button
        resumeButton = createButton(text: "Resume", width: 160, height: 50)
        resumeButton.position = CGPoint(x: 0, y: 0)
        resumeButton.name = "resumeButton"
        addChild(resumeButton)

        // Quit button
        quitButton = createButton(text: "Quit", width: 160, height: 50)
        quitButton.position = CGPoint(x: 0, y: -70)
        quitButton.name = "quitButton"
        addChild(quitButton)
    }

    private func createButton(text: String, width: CGFloat, height: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        button.fillColor = SKColor.white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.lineWidth = 2

        let label = SKLabelNode(fontNamed: UIConfig.fontName)
        label.text = text
        label.fontSize = UIConfig.bodyFontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)

        return button
    }

    func handleTouch(at location: CGPoint) {
        // Convert to local coordinates and check button frames
        let localLocation = convert(location, from: parent ?? self)

        if resumeButton.frame.contains(localLocation) {
            delegate?.resumeTapped()
        } else if quitButton.frame.contains(localLocation) {
            delegate?.quitTapped()
        }
    }
}
