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
        guard let scene = scene else { return }

        // HUD layer (always visible during gameplay)
        hudLayer = SKNode()
        hudLayer.zPosition = GameConfig.ZPosition.ui
        scene.addChild(hudLayer)

        // Overlay layer (for screens that pause gameplay)
        overlayLayer = SKNode()
        overlayLayer.zPosition = GameConfig.ZPosition.overlay
        scene.addChild(overlayLayer)
    }

    private func setupHUD() {
        guard let scene = scene else { return }

        let screenWidth = scene.size.width
        let screenHeight = scene.size.height
        let safeAreaTop: CGFloat = 50

        // Health bar (top left)
        healthBar = HealthBar(width: UIConfig.healthBarWidth, height: UIConfig.healthBarHeight)
        healthBar.position = CGPoint(x: 20 + UIConfig.healthBarWidth / 2, y: screenHeight - safeAreaTop)
        hudLayer.addChild(healthBar)

        // XP bar (below health bar)
        xpBar = XPBar(width: UIConfig.xpBarWidth, height: UIConfig.xpBarHeight)
        xpBar.position = CGPoint(x: 20 + UIConfig.xpBarWidth / 2, y: screenHeight - safeAreaTop - 30)
        hudLayer.addChild(xpBar)

        // Level label (next to XP bar)
        levelLabel = createLabel(text: "Lv.1", fontSize: UIConfig.smallFontSize)
        levelLabel.position = CGPoint(x: 20 + UIConfig.xpBarWidth + 30, y: screenHeight - safeAreaTop - 30)
        hudLayer.addChild(levelLabel)

        // Wave label (top center)
        waveLabel = createLabel(text: "Wave 1", fontSize: UIConfig.titleFontSize)
        waveLabel.position = CGPoint(x: screenWidth / 2, y: screenHeight - safeAreaTop)
        hudLayer.addChild(waveLabel)

        // Timer label (below wave)
        timerLabel = createLabel(text: "0:30", fontSize: UIConfig.bodyFontSize)
        timerLabel.position = CGPoint(x: screenWidth / 2, y: screenHeight - safeAreaTop - 35)
        hudLayer.addChild(timerLabel)

        // Kill count (top right)
        killCountLabel = createLabel(text: "Kills: 0", fontSize: UIConfig.bodyFontSize)
        killCountLabel.horizontalAlignmentMode = .right
        killCountLabel.position = CGPoint(x: screenWidth - 20, y: screenHeight - safeAreaTop)
        hudLayer.addChild(killCountLabel)

        // Pause button (top right corner)
        let pauseButton = createButton(text: "II", size: CGSize(width: 44, height: 44))
        pauseButton.position = CGPoint(x: screenWidth - 40, y: screenHeight - safeAreaTop - 50)
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
        let xPos = scene.size.width - 60
        let yPos: CGFloat = 150 + CGFloat(buttonIndex) * 70

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
        // Check pause button
        if let pauseButton = hudLayer.childNode(withName: "pauseButton"),
           pauseButton.contains(location) {
            delegate?.pauseButtonPressed()
            return true
        }

        // Check ability buttons
        for (type, button) in abilityButtons {
            if button.contains(button.convert(location, from: hudLayer)) {
                delegate?.abilityButtonPressed(type)
                return true
            }
        }

        // Check overlay screens
        if isOverlayActive {
            upgradeScreen?.handleTouch(at: overlayLayer.convert(location, from: scene!))
            deathScreen?.handleTouch(at: overlayLayer.convert(location, from: scene!))
            pauseScreen?.handleTouch(at: overlayLayer.convert(location, from: scene!))
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
    }

    func quitTapped() {
        hidePauseScreen()
        delegate?.mainMenuButtonPressed()
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
    private var cooldownOverlay: SKShapeNode!
    private var iconLabel: SKLabelNode!

    private let size: CGFloat = 50

    init(abilityType: UpgradeType) {
        self.abilityType = abilityType
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // Background
        background = SKShapeNode(circleOfRadius: size / 2)
        background.fillColor = abilityType.color.withAlphaComponent(0.6)
        background.strokeColor = .white
        background.lineWidth = 2
        addChild(background)

        // Cooldown overlay
        cooldownOverlay = SKShapeNode(circleOfRadius: size / 2)
        cooldownOverlay.fillColor = SKColor.black.withAlphaComponent(0.7)
        cooldownOverlay.strokeColor = .clear
        cooldownOverlay.isHidden = true
        addChild(cooldownOverlay)

        // Icon (first letter of ability)
        iconLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        iconLabel.text = String(abilityType.displayName.prefix(1))
        iconLabel.fontSize = UIConfig.bodyFontSize
        iconLabel.fontColor = .white
        iconLabel.verticalAlignmentMode = .center
        addChild(iconLabel)

        isUserInteractionEnabled = true
    }

    func updateCooldown(remaining: TimeInterval, total: TimeInterval) {
        if remaining > 0 {
            cooldownOverlay.isHidden = false
            let percent = remaining / total
            cooldownOverlay.yScale = CGFloat(percent)
        } else {
            cooldownOverlay.isHidden = true
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.abilityButtonTapped(abilityType)
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

    init(size: CGSize, choices: [Upgrade]) {
        self.choices = choices
        super.init()
        setup(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(size: CGSize) {
        // Dim background
        let background = SKShapeNode(rectOf: size)
        background.fillColor = SKColor.black.withAlphaComponent(0.8)
        background.strokeColor = .clear
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(background)

        // Title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "Choose an Upgrade"
        title.fontSize = UIConfig.titleFontSize
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 100)
        addChild(title)

        // Create upgrade cards
        let cardWidth: CGFloat = 100
        let cardHeight: CGFloat = 150
        let cardSpacing: CGFloat = 20
        let totalWidth = CGFloat(choices.count) * cardWidth + CGFloat(choices.count - 1) * cardSpacing
        let startX = (size.width - totalWidth) / 2 + cardWidth / 2

        for (index, upgrade) in choices.enumerated() {
            let card = UpgradeCard(upgrade: upgrade, size: CGSize(width: cardWidth, height: cardHeight))
            card.position = CGPoint(
                x: startX + CGFloat(index) * (cardWidth + cardSpacing),
                y: size.height / 2
            )
            card.name = "card_\(index)"
            addChild(card)
            cards.append(card)
        }
    }

    func handleTouch(at location: CGPoint) {
        for (index, card) in cards.enumerated() {
            if card.contains(location) {
                delegate?.didSelectUpgrade(choices[index])

                // Visual feedback
                card.run(SKAction.sequence([
                    SKAction.scale(to: 1.2, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
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
        // Card background
        let background = SKShapeNode(rectOf: size, cornerRadius: 10)
        background.fillColor = upgrade.color.withAlphaComponent(0.3)
        background.strokeColor = upgrade.color
        background.lineWidth = 3
        addChild(background)

        // Icon circle
        let iconCircle = SKShapeNode(circleOfRadius: 25)
        iconCircle.fillColor = upgrade.color.withAlphaComponent(0.5)
        iconCircle.strokeColor = .white
        iconCircle.lineWidth = 2
        iconCircle.position = CGPoint(x: 0, y: size.height / 2 - 45)
        addChild(iconCircle)

        // Icon letter
        let iconLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        iconLabel.text = String(upgrade.displayName.prefix(1))
        iconLabel.fontSize = 24
        iconLabel.fontColor = .white
        iconLabel.verticalAlignmentMode = .center
        iconCircle.addChild(iconLabel)

        // Name
        let nameLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        nameLabel.text = upgrade.displayName
        nameLabel.fontSize = UIConfig.smallFontSize
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: 0)
        nameLabel.numberOfLines = 2
        nameLabel.preferredMaxLayoutWidth = size.width - 10
        addChild(nameLabel)

        // Description
        let descLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        descLabel.text = upgrade.type.description
        descLabel.fontSize = 10
        descLabel.fontColor = SKColor.white.withAlphaComponent(0.8)
        descLabel.position = CGPoint(x: 0, y: -size.height / 2 + 30)
        descLabel.numberOfLines = 2
        descLabel.preferredMaxLayoutWidth = size.width - 10
        addChild(descLabel)
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
        // Background
        let background = SKShapeNode(rectOf: size)
        background.fillColor = SKColor.black.withAlphaComponent(0.9)
        background.strokeColor = .clear
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(background)

        // Game Over title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "GAME OVER"
        title.fontSize = 40
        title.fontColor = SKColor.red
        title.position = CGPoint(x: size.width / 2, y: size.height - 120)
        addChild(title)

        // Stats
        let statsY = size.height / 2 + 50
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
            label.position = CGPoint(x: size.width / 2, y: statsY - CGFloat(index) * statsSpacing)
            addChild(label)
        }

        // Restart button
        restartButton = createButton(text: "Play Again", width: 180, height: 50)
        restartButton.position = CGPoint(x: size.width / 2, y: 180)
        restartButton.name = "restartButton"
        addChild(restartButton)

        // Menu button
        menuButton = createButton(text: "Main Menu", width: 180, height: 50)
        menuButton.position = CGPoint(x: size.width / 2, y: 110)
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
        // Background
        let background = SKShapeNode(rectOf: size)
        background.fillColor = SKColor.black.withAlphaComponent(0.8)
        background.strokeColor = .clear
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(background)

        // Title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "PAUSED"
        title.fontSize = UIConfig.titleFontSize
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80)
        addChild(title)

        // Resume button
        resumeButton = createButton(text: "Resume", width: 160, height: 50)
        resumeButton.position = CGPoint(x: size.width / 2, y: size.height / 2)
        resumeButton.name = "resumeButton"
        addChild(resumeButton)

        // Quit button
        quitButton = createButton(text: "Quit", width: 160, height: 50)
        quitButton.position = CGPoint(x: size.width / 2, y: size.height / 2 - 70)
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
        if resumeButton.contains(location) {
            delegate?.resumeTapped()
        } else if quitButton.contains(location) {
            delegate?.quitTapped()
        }
    }
}
