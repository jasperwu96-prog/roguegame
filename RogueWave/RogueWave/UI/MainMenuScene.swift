//
//  MainMenuScene.swift
//  RogueWave
//
//  Main menu screen with all navigation options
//

import SpriteKit

class MainMenuScene: SKScene {

    // MARK: - Properties

    private var backgroundLayer: SKNode!
    private var menuContainer: SKNode!
    private var currentSubMenu: SKNode?

    // Buttons
    private var playButton: MenuButton!
    private var statsButton: MenuButton!
    private var achievementsButton: MenuButton!
    private var charactersButton: MenuButton!
    private var upgradesButton: MenuButton!
    private var challengesButton: MenuButton!
    private var settingsButton: MenuButton!

    // Selected character
    private var selectedCharacterClass: CharacterClass = .knight

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        setupBackground()
        setupTitle()
        setupMenuButtons()
        setupFooter()

        // Play menu music
        AudioManager.shared.playBackgroundMusic()
    }

    // MARK: - Setup

    private func setupBackground() {
        backgroundColor = SKColor(red: 0.08, green: 0.1, blue: 0.15, alpha: 1.0)

        backgroundLayer = SKNode()
        addChild(backgroundLayer)

        // Animated background particles
        for _ in 0..<30 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            particle.fillColor = SKColor(red: 0.3, green: 0.5, blue: 0.8, alpha: CGFloat.random(in: 0.1...0.3))
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            backgroundLayer.addChild(particle)

            // Floating animation
            let duration = TimeInterval.random(in: 3...6)
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: 50, duration: duration)
            let fadeOut = SKAction.fadeOut(withDuration: duration)
            let reset = SKAction.run {
                particle.position = CGPoint(
                    x: CGFloat.random(in: 0...self.size.width),
                    y: -10
                )
                particle.alpha = CGFloat.random(in: 0.1...0.3)
            }
            particle.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([moveUp, fadeOut]),
                reset
            ])))
        }

        // Gradient overlay at bottom
        let gradient = SKShapeNode(rectOf: CGSize(width: size.width, height: 200))
        gradient.fillColor = SKColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.8)
        gradient.strokeColor = .clear
        gradient.position = CGPoint(x: size.width / 2, y: 100)
        backgroundLayer.addChild(gradient)
    }

    private func setupTitle() {
        // Game title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "ROGUE WAVE"
        title.fontSize = 48
        title.fontColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        title.position = CGPoint(x: size.width / 2, y: size.height - 100)
        addChild(title)

        // Glow effect
        let glow = SKLabelNode(fontNamed: UIConfig.fontName)
        glow.text = "ROGUE WAVE"
        glow.fontSize = 48
        glow.fontColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.3)
        glow.position = CGPoint(x: size.width / 2, y: size.height - 100)
        glow.setScale(1.05)
        addChild(glow)

        // Pulse animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 1.5),
            SKAction.scale(to: 1.05, duration: 1.5)
        ]))
        glow.run(pulse)

        // Subtitle
        let subtitle = SKLabelNode(fontNamed: UIConfig.fontName)
        subtitle.text = "Survive the Endless Horde"
        subtitle.fontSize = 16
        subtitle.fontColor = SKColor(white: 0.7, alpha: 1.0)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 140)
        addChild(subtitle)
    }

    private func setupMenuButtons() {
        menuContainer = SKNode()
        menuContainer.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        addChild(menuContainer)

        let buttonSpacing: CGFloat = 55

        // Main play button (larger, prominent)
        playButton = MenuButton(
            text: "START RUN",
            width: 220,
            height: 55,
            style: .primary
        )
        playButton.position = CGPoint(x: 0, y: buttonSpacing * 2)
        playButton.onTap = { [weak self] in self?.startGame() }
        menuContainer.addChild(playButton)

        // Character selection button
        charactersButton = MenuButton(
            text: "CHARACTERS",
            width: 180,
            height: 45,
            style: .secondary
        )
        charactersButton.position = CGPoint(x: 0, y: buttonSpacing * 0.8)
        charactersButton.onTap = { [weak self] in self?.showCharacters() }
        menuContainer.addChild(charactersButton)

        // Two-column layout for other buttons
        let colOffset: CGFloat = 95

        // Left column
        upgradesButton = MenuButton(
            text: "UPGRADES",
            width: 160,
            height: 40,
            style: .normal
        )
        upgradesButton.position = CGPoint(x: -colOffset, y: -buttonSpacing * 0.5)
        upgradesButton.onTap = { [weak self] in self?.showUpgrades() }
        menuContainer.addChild(upgradesButton)

        achievementsButton = MenuButton(
            text: "ACHIEVEMENTS",
            width: 160,
            height: 40,
            style: .normal
        )
        achievementsButton.position = CGPoint(x: -colOffset, y: -buttonSpacing * 1.5)
        achievementsButton.onTap = { [weak self] in self?.showAchievements() }
        menuContainer.addChild(achievementsButton)

        // Right column
        statsButton = MenuButton(
            text: "STATS",
            width: 160,
            height: 40,
            style: .normal
        )
        statsButton.position = CGPoint(x: colOffset, y: -buttonSpacing * 0.5)
        statsButton.onTap = { [weak self] in self?.showStats() }
        menuContainer.addChild(statsButton)

        challengesButton = MenuButton(
            text: "CHALLENGES",
            width: 160,
            height: 40,
            style: .normal
        )
        challengesButton.position = CGPoint(x: colOffset, y: -buttonSpacing * 1.5)
        challengesButton.onTap = { [weak self] in self?.showChallenges() }
        menuContainer.addChild(challengesButton)

        // Settings at bottom
        settingsButton = MenuButton(
            text: "SETTINGS",
            width: 140,
            height: 35,
            style: .minimal
        )
        settingsButton.position = CGPoint(x: 0, y: -buttonSpacing * 2.8)
        settingsButton.onTap = { [weak self] in self?.showSettings() }
        menuContainer.addChild(settingsButton)
    }

    private func setupFooter() {
        // Version info
        let version = SKLabelNode(fontNamed: UIConfig.fontName)
        version.text = "v1.0.0"
        version.fontSize = 10
        version.fontColor = SKColor(white: 0.4, alpha: 1.0)
        version.position = CGPoint(x: size.width - 40, y: 20)
        addChild(version)

        // Quick stats display
        let stats = GameManager.shared
        let quickStats = SKLabelNode(fontNamed: UIConfig.fontName)
        quickStats.text = "Best Wave: \(stats.metaProgression.highestWave) | Total Kills: \(stats.metaProgression.totalKills)"
        quickStats.fontSize = 12
        quickStats.fontColor = SKColor(white: 0.5, alpha: 1.0)
        quickStats.position = CGPoint(x: size.width / 2, y: 30)
        addChild(quickStats)
    }

    // MARK: - Touch Handling

    private var touchStartLocation: CGPoint?
    private var lastTouchLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartLocation = location
        lastTouchLocation = location

        // If submenu is open, check close button only (tap handling done on touchesEnded)
        if let submenu = currentSubMenu as? SubMenuView {
            let submenuLocation = touch.location(in: submenu)

            // Check close button
            if let closeButton = submenu.childNode(withName: "closeButton") {
                if closeButton.contains(submenuLocation) {
                    closeSubMenu()
                    AudioManager.shared.playSFX(.buttonPress, on: self)
                    return
                }
            }
            return
        }

        // Handle menu button touches
        handleButtonTouch(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Handle scrolling in character select view
        if let charSelect = currentSubMenu as? CharacterSelectView,
           let lastLocation = lastTouchLocation {
            let submenuLocation = touch.location(in: charSelect)
            let lastSubmenuLocation = convert(lastLocation, to: charSelect)
            charSelect.handleDrag(from: lastSubmenuLocation, to: submenuLocation)
        }

        lastTouchLocation = location
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if this was a tap (not a drag)
        if let startLocation = touchStartLocation {
            let distance = hypot(location.x - startLocation.x, location.y - startLocation.y)
            let wasTap = distance < 20  // Threshold for tap vs drag

            // Handle tap on submenu elements
            if wasTap, let submenu = currentSubMenu as? SubMenuView {
                let submenuLocation = touch.location(in: submenu)
                if submenu.handleTouch(at: submenuLocation) {
                    AudioManager.shared.playSFX(.buttonPress, on: self)
                }
            }
        }

        touchStartLocation = nil
        lastTouchLocation = nil
    }

    private func handleButtonTouch(at location: CGPoint) {
        let menuLocation = menuContainer.convert(location, from: self)

        let buttons = [playButton, charactersButton, upgradesButton,
                       achievementsButton, statsButton, challengesButton, settingsButton]

        for button in buttons {
            if let btn = button {
                // Convert to button's local coordinate system
                let buttonLocalPoint = btn.convert(menuLocation, from: menuContainer)
                if btn.contains(buttonLocalPoint) {
                    btn.triggerTap()
                    AudioManager.shared.playSFX(.buttonPress, on: self)
                    break
                }
            }
        }
    }

    // MARK: - Navigation

    private func startGame() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = .aspectFill
        // Pass selected character to game scene
        view?.presentScene(gameScene, transition: transition)
    }

    private func showCharacters() {
        showSubMenu(CharacterSelectView(size: size, selectedClass: selectedCharacterClass) { [weak self] selectedClass in
            self?.selectedCharacterClass = selectedClass
            self?.closeSubMenu()
        })
    }

    private func showStats() {
        showSubMenu(StatsView(size: size))
    }

    private func showAchievements() {
        showSubMenu(AchievementsView(size: size))
    }

    private func showUpgrades() {
        showSubMenu(UpgradesView(size: size))
    }

    private func showChallenges() {
        showSubMenu(ChallengesView(size: size))
    }

    private func showSettings() {
        showSubMenu(SettingsView(size: size))
    }

    private func showSubMenu(_ submenu: SKNode) {
        // Close existing submenu
        currentSubMenu?.removeFromParent()

        // Hide main menu completely
        menuContainer.isHidden = true
        backgroundLayer.isHidden = true

        // Add submenu
        submenu.alpha = 0
        addChild(submenu)
        submenu.run(SKAction.fadeIn(withDuration: 0.2))
        currentSubMenu = submenu
    }

    private func closeSubMenu() {
        currentSubMenu?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        currentSubMenu = nil

        // Show main menu again
        menuContainer.isHidden = false
        backgroundLayer.isHidden = false
        menuContainer.alpha = 1.0
    }
}

// MARK: - Menu Button

class MenuButton: SKNode {

    enum Style {
        case primary
        case secondary
        case normal
        case minimal
    }

    var onTap: (() -> Void)?

    private let background: SKShapeNode
    private let label: SKLabelNode

    init(text: String, width: CGFloat, height: CGFloat, style: Style) {
        background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 4)
        label = SKLabelNode(fontNamed: UIConfig.fontName)

        super.init()

        // Style the button
        switch style {
        case .primary:
            background.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
            background.strokeColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
            background.lineWidth = 3
            background.glowWidth = 5
            label.fontSize = 22
            label.fontColor = .white

        case .secondary:
            background.fillColor = SKColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1.0)
            background.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)
            background.lineWidth = 2
            label.fontSize = 18
            label.fontColor = .white

        case .normal:
            background.fillColor = SKColor(red: 0.12, green: 0.15, blue: 0.2, alpha: 1.0)
            background.strokeColor = SKColor(red: 0.25, green: 0.3, blue: 0.4, alpha: 1.0)
            background.lineWidth = 2
            label.fontSize = 15
            label.fontColor = SKColor(white: 0.9, alpha: 1.0)

        case .minimal:
            background.fillColor = SKColor(white: 0.1, alpha: 0.5)
            background.strokeColor = SKColor(white: 0.3, alpha: 0.5)
            background.lineWidth = 1
            label.fontSize = 13
            label.fontColor = SKColor(white: 0.7, alpha: 1.0)
        }

        addChild(background)

        label.text = text
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func triggerTap() {
        // Visual feedback
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.05)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        run(SKAction.sequence([scaleDown, scaleUp]))

        onTap?()
    }

    override func contains(_ p: CGPoint) -> Bool {
        return background.contains(p)
    }
}
