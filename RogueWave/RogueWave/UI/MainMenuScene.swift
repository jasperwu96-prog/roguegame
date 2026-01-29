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
    private var titleContainer: SKNode!
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

    // Character preview
    private var characterPreviewContainer: SKNode?
    private var characterNameLabel: SKLabelNode?

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
        backgroundColor = SKColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0)

        backgroundLayer = SKNode()
        addChild(backgroundLayer)

        // Subtle radial gradient effect (darker at edges)
        let vignette = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        vignette.fillColor = SKColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.6)
        vignette.strokeColor = .clear
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundLayer.addChild(vignette)

        // Grid lines for tech aesthetic
        for i in 0..<10 {
            let yPos = CGFloat(i) * (size.height / 10)
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 0.5))
            line.fillColor = SKColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.15)
            line.strokeColor = .clear
            line.position = CGPoint(x: size.width / 2, y: yPos)
            backgroundLayer.addChild(line)
        }

        // Animated background particles - more particles, varied colors
        for _ in 0..<50 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.5))
            let blueVariant = CGFloat.random(in: 0.6...1.0)
            particle.fillColor = SKColor(red: 0.2 * blueVariant, green: 0.4 * blueVariant, blue: blueVariant, alpha: CGFloat.random(in: 0.15...0.4))
            particle.strokeColor = .clear
            particle.glowWidth = 1
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            backgroundLayer.addChild(particle)

            // Floating animation with varied speeds
            let duration = TimeInterval.random(in: 4...8)
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -30...30), y: size.height + 20, duration: duration)
            let reset = SKAction.run {
                particle.position = CGPoint(
                    x: CGFloat.random(in: 0...self.size.width),
                    y: -10
                )
                particle.alpha = CGFloat.random(in: 0.15...0.4)
            }
            particle.run(SKAction.repeatForever(SKAction.sequence([moveUp, reset])))
        }

        // Accent glow at top
        let topGlow = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.8, height: 150))
        topGlow.fillColor = SKColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 0.15)
        topGlow.strokeColor = .clear
        topGlow.position = CGPoint(x: size.width / 2, y: size.height - 50)
        backgroundLayer.addChild(topGlow)
    }

    private func setupTitle() {
        // Container for title elements (will be hidden with menu)
        titleContainer = SKNode()
        addChild(titleContainer)

        // Decorative line above title
        let topLine = SKShapeNode(rectOf: CGSize(width: 180, height: 2), cornerRadius: 1)
        topLine.fillColor = SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.6)
        topLine.strokeColor = .clear
        topLine.position = CGPoint(x: size.width / 2, y: size.height - 55)
        titleContainer.addChild(topLine)

        // Game title with shadow
        let titleShadow = SKLabelNode(fontNamed: UIConfig.fontName)
        titleShadow.text = "ROGUE WAVE"
        titleShadow.fontSize = 48
        titleShadow.fontColor = SKColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 0.8)
        titleShadow.position = CGPoint(x: size.width / 2 + 3, y: size.height - 103)
        titleContainer.addChild(titleShadow)

        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "ROGUE WAVE"
        title.fontSize = 48
        title.fontColor = SKColor(red: 0.4, green: 0.75, blue: 1.0, alpha: 1.0)
        title.position = CGPoint(x: size.width / 2, y: size.height - 100)
        titleContainer.addChild(title)

        // Glow effect
        let glow = SKLabelNode(fontNamed: UIConfig.fontName)
        glow.text = "ROGUE WAVE"
        glow.fontSize = 48
        glow.fontColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.25)
        glow.position = CGPoint(x: size.width / 2, y: size.height - 100)
        glow.setScale(1.06)
        titleContainer.addChild(glow)

        // Pulse animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.09, duration: 2.0),
            SKAction.scale(to: 1.06, duration: 2.0)
        ]))
        glow.run(pulse)

        // Decorative line below title
        let bottomLine = SKShapeNode(rectOf: CGSize(width: 120, height: 1), cornerRadius: 0.5)
        bottomLine.fillColor = SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.4)
        bottomLine.strokeColor = .clear
        bottomLine.position = CGPoint(x: size.width / 2, y: size.height - 125)
        titleContainer.addChild(bottomLine)

        // Subtitle with better styling
        let subtitle = SKLabelNode(fontNamed: UIConfig.fontName)
        subtitle.text = "Survive the Endless Horde"
        subtitle.fontSize = 14
        subtitle.fontColor = SKColor(red: 0.6, green: 0.7, blue: 0.8, alpha: 1.0)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 145)
        titleContainer.addChild(subtitle)
    }

    private func setupMenuButtons() {
        menuContainer = SKNode()
        menuContainer.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        addChild(menuContainer)

        let buttonSpacing: CGFloat = 55

        // Character preview above play button
        setupCharacterPreview()

        // Main play button (larger, prominent)
        playButton = MenuButton(
            text: "START RUN",
            width: 220,
            height: 55,
            style: .primary
        )
        playButton.position = CGPoint(x: 0, y: buttonSpacing * 1.5)
        playButton.onTap = { [weak self] in self?.startGame() }
        menuContainer.addChild(playButton)

        // Character selection button
        charactersButton = MenuButton(
            text: "CHARACTERS",
            width: 180,
            height: 45,
            style: .secondary
        )
        charactersButton.position = CGPoint(x: 0, y: buttonSpacing * 0.3)
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
        upgradesButton.position = CGPoint(x: -colOffset, y: -buttonSpacing * 0.8)
        upgradesButton.onTap = { [weak self] in self?.showUpgrades() }
        menuContainer.addChild(upgradesButton)

        achievementsButton = MenuButton(
            text: "ACHIEVEMENTS",
            width: 160,
            height: 40,
            style: .normal
        )
        achievementsButton.position = CGPoint(x: -colOffset, y: -buttonSpacing * 1.8)
        achievementsButton.onTap = { [weak self] in self?.showAchievements() }
        menuContainer.addChild(achievementsButton)

        // Right column
        statsButton = MenuButton(
            text: "STATS",
            width: 160,
            height: 40,
            style: .normal
        )
        statsButton.position = CGPoint(x: colOffset, y: -buttonSpacing * 0.8)
        statsButton.onTap = { [weak self] in self?.showStats() }
        menuContainer.addChild(statsButton)

        challengesButton = MenuButton(
            text: "CHALLENGES",
            width: 160,
            height: 40,
            style: .normal
        )
        challengesButton.position = CGPoint(x: colOffset, y: -buttonSpacing * 1.8)
        challengesButton.onTap = { [weak self] in self?.showChallenges() }
        menuContainer.addChild(challengesButton)

        // Settings at bottom
        settingsButton = MenuButton(
            text: "SETTINGS",
            width: 140,
            height: 35,
            style: .minimal
        )
        settingsButton.position = CGPoint(x: 0, y: -buttonSpacing * 3.0)
        settingsButton.onTap = { [weak self] in self?.showSettings() }
        menuContainer.addChild(settingsButton)
    }

    private func setupCharacterPreview() {
        let previewContainer = SKNode()
        previewContainer.position = CGPoint(x: 0, y: 55 * 3)  // Above play button
        menuContainer.addChild(previewContainer)
        characterPreviewContainer = previewContainer

        updateCharacterPreview()
    }

    private func updateCharacterPreview() {
        guard let container = characterPreviewContainer else { return }
        container.removeAllChildren()

        // Character portrait background
        let bgGlow = SKShapeNode(circleOfRadius: 42)
        bgGlow.fillColor = selectedCharacterClass.color.withAlphaComponent(0.2)
        bgGlow.strokeColor = selectedCharacterClass.color.withAlphaComponent(0.5)
        bgGlow.lineWidth = 2
        bgGlow.glowWidth = 8
        container.addChild(bgGlow)

        let bg = SKShapeNode(circleOfRadius: 35)
        bg.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)
        bg.strokeColor = selectedCharacterClass.color
        bg.lineWidth = 2
        container.addChild(bg)

        // Create character portrait
        let portraitContainer = SKNode()
        createMenuCharacterPortrait(for: selectedCharacterClass, in: portraitContainer, scale: 0.55)
        container.addChild(portraitContainer)

        // Character name below
        let nameLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        nameLabel.text = selectedCharacterClass.rawValue.uppercased()
        nameLabel.fontSize = 11
        nameLabel.fontColor = selectedCharacterClass.color
        nameLabel.position = CGPoint(x: 0, y: -55)
        container.addChild(nameLabel)
        characterNameLabel = nameLabel
    }

    private func createMenuCharacterPortrait(for charClass: CharacterClass, in container: SKNode, scale: CGFloat) {
        let s: CGFloat = 40 * scale

        switch charClass {
        case .knight:
            let helmet = SKShapeNode(circleOfRadius: s * 0.8)
            helmet.fillColor = SKColor(red: 0.75, green: 0.75, blue: 0.8, alpha: 1.0)
            helmet.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
            helmet.lineWidth = 2
            container.addChild(helmet)

            let visor = SKShapeNode(rectOf: CGSize(width: s * 0.8, height: s * 0.15))
            visor.fillColor = SKColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0)
            visor.strokeColor = .clear
            visor.position = CGPoint(x: 0, y: s * 0.1)
            helmet.addChild(visor)

            let plume = SKShapeNode(rectOf: CGSize(width: s * 0.15, height: s * 0.5))
            plume.fillColor = SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)
            plume.strokeColor = .clear
            plume.position = CGPoint(x: 0, y: s * 0.6)
            helmet.addChild(plume)

            for xOffset in [-s * 0.2, s * 0.2] {
                let eye = SKShapeNode(circleOfRadius: s * 0.08)
                eye.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 3
                eye.position = CGPoint(x: xOffset, y: s * 0.1)
                helmet.addChild(eye)
            }

        case .rogue:
            let hood = SKShapeNode(circleOfRadius: s * 0.8)
            hood.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.2, alpha: 1.0)
            hood.strokeColor = SKColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)
            hood.lineWidth = 2
            container.addChild(hood)

            let pointPath = CGMutablePath()
            pointPath.move(to: CGPoint(x: -s * 0.3, y: s * 0.4))
            pointPath.addLine(to: CGPoint(x: 0, y: s * 0.9))
            pointPath.addLine(to: CGPoint(x: s * 0.3, y: s * 0.4))
            pointPath.closeSubpath()
            let point = SKShapeNode(path: pointPath)
            point.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.2, alpha: 1.0)
            point.strokeColor = .clear
            hood.addChild(point)

            let face = SKShapeNode(circleOfRadius: s * 0.4)
            face.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)
            face.strokeColor = .clear
            face.position = CGPoint(x: 0, y: -s * 0.1)
            hood.addChild(face)

            for xOffset in [-s * 0.15, s * 0.15] {
                let eye = SKShapeNode(circleOfRadius: s * 0.08)
                eye.fillColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 4
                eye.position = CGPoint(x: xOffset, y: -s * 0.05)
                hood.addChild(eye)
            }

        case .mage:
            let face = SKShapeNode(circleOfRadius: s * 0.5)
            face.fillColor = SKColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1.0)
            face.strokeColor = .clear
            face.position = CGPoint(x: 0, y: -s * 0.15)
            container.addChild(face)

            let beard = SKShapeNode(ellipseOf: CGSize(width: s * 0.5, height: s * 0.4))
            beard.fillColor = SKColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
            beard.strokeColor = .clear
            beard.position = CGPoint(x: 0, y: -s * 0.5)
            face.addChild(beard)

            let hatPath = CGMutablePath()
            hatPath.move(to: CGPoint(x: -s * 0.6, y: 0))
            hatPath.addLine(to: CGPoint(x: 0, y: s * 1.2))
            hatPath.addLine(to: CGPoint(x: s * 0.6, y: 0))
            hatPath.closeSubpath()
            let hat = SKShapeNode(path: hatPath)
            hat.fillColor = SKColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 1.0)
            hat.strokeColor = SKColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1.0)
            hat.lineWidth = 2
            hat.position = CGPoint(x: 0, y: s * 0.3)
            container.addChild(hat)

            for xOffset in [-s * 0.15, s * 0.15] {
                let eye = SKShapeNode(circleOfRadius: s * 0.06)
                eye.fillColor = SKColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 3
                eye.position = CGPoint(x: xOffset, y: -s * 0.1)
                face.addChild(eye)
            }

        case .berserker:
            let head = SKShapeNode(circleOfRadius: s * 0.7)
            head.fillColor = SKColor(red: 0.85, green: 0.7, blue: 0.6, alpha: 1.0)
            head.strokeColor = .clear
            container.addChild(head)

            let hair = SKShapeNode(ellipseOf: CGSize(width: s * 1.6, height: s * 0.8))
            hair.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1.0)
            hair.strokeColor = .clear
            hair.position = CGPoint(x: 0, y: s * 0.3)
            head.addChild(hair)

            let scar = SKShapeNode(rectOf: CGSize(width: s * 0.08, height: s * 0.4))
            scar.fillColor = SKColor(red: 0.7, green: 0.4, blue: 0.4, alpha: 1.0)
            scar.strokeColor = .clear
            scar.position = CGPoint(x: s * 0.2, y: s * 0.1)
            scar.zRotation = 0.3
            head.addChild(scar)

            for xOffset in [-s * 0.2, s * 0.2] {
                let eye = SKShapeNode(circleOfRadius: s * 0.1)
                eye.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 4
                eye.position = CGPoint(x: xOffset, y: 0)
                head.addChild(eye)
            }
        }
    }

    private func setupFooter() {
        // Footer background
        let footerBg = SKShapeNode(rectOf: CGSize(width: size.width, height: 60))
        footerBg.fillColor = SKColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 0.9)
        footerBg.strokeColor = .clear
        footerBg.position = CGPoint(x: size.width / 2, y: 30)
        addChild(footerBg)

        // Top border line
        let borderLine = SKShapeNode(rectOf: CGSize(width: size.width * 0.85, height: 1))
        borderLine.fillColor = SKColor(red: 0.2, green: 0.35, blue: 0.5, alpha: 0.5)
        borderLine.strokeColor = .clear
        borderLine.position = CGPoint(x: size.width / 2, y: 60)
        addChild(borderLine)

        // Version info
        let version = SKLabelNode(fontNamed: UIConfig.fontName)
        version.text = "v1.0.0"
        version.fontSize = 10
        version.fontColor = SKColor(white: 0.35, alpha: 1.0)
        version.position = CGPoint(x: size.width - 35, y: 12)
        addChild(version)

        // Quick stats display with icons
        let stats = GameManager.shared

        // Wave icon and stat
        let waveLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        waveLabel.text = "Best Wave: \(stats.metaProgression.highestWave)"
        waveLabel.fontSize = 12
        waveLabel.fontColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        waveLabel.horizontalAlignmentMode = .right
        waveLabel.position = CGPoint(x: size.width / 2 - 20, y: 35)
        addChild(waveLabel)

        // Separator
        let separator = SKShapeNode(rectOf: CGSize(width: 1, height: 20))
        separator.fillColor = SKColor(white: 0.3, alpha: 0.6)
        separator.strokeColor = .clear
        separator.position = CGPoint(x: size.width / 2, y: 40)
        addChild(separator)

        // Kills stat
        let killsLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        killsLabel.text = "Total Kills: \(stats.metaProgression.totalKills)"
        killsLabel.fontSize = 12
        killsLabel.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.4, alpha: 1.0)
        killsLabel.horizontalAlignmentMode = .left
        killsLabel.position = CGPoint(x: size.width / 2 + 20, y: 35)
        addChild(killsLabel)
    }

    // MARK: - Touch Handling

    private var touchStartLocation: CGPoint?
    private var isDragging: Bool = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartLocation = location
        isDragging = false

        // If submenu is open, check close button and start drag tracking
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

            // Start drag tracking for scrollable views
            if let charSelect = submenu as? CharacterSelectView {
                charSelect.handleDragBegan(at: submenuLocation)
            } else if let achievements = submenu as? AchievementsView {
                achievements.handleDragBegan(at: submenuLocation)
            }
            return
        }

        // Handle menu button touches
        handleButtonTouch(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if we've moved enough to be considered dragging
        if let startLocation = touchStartLocation {
            let distance = hypot(location.x - startLocation.x, location.y - startLocation.y)
            if distance > 10 {
                isDragging = true
            }
        }

        // Handle scrolling in scrollable views
        if let submenu = currentSubMenu as? SubMenuView {
            let submenuLocation = touch.location(in: submenu)
            if let charSelect = submenu as? CharacterSelectView {
                charSelect.handleDragMoved(to: submenuLocation)
            } else if let achievements = submenu as? AchievementsView {
                achievements.handleDragMoved(to: submenuLocation)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Handle drag end for scrollable views
        if let charSelect = currentSubMenu as? CharacterSelectView {
            charSelect.handleDragEnded()
        } else if let achievements = currentSubMenu as? AchievementsView {
            achievements.handleDragEnded()
        }

        // Check if this was a tap (not a drag)
        if !isDragging, let submenu = currentSubMenu as? SubMenuView {
            let submenuLocation = touch.location(in: submenu)
            if submenu.handleTouch(at: submenuLocation) {
                AudioManager.shared.playSFX(.buttonPress, on: self)
            }
        }

        touchStartLocation = nil
        isDragging = false
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
        gameScene.selectedCharacterClass = selectedCharacterClass
        view?.presentScene(gameScene, transition: transition)
    }

    private func showCharacters() {
        showSubMenu(CharacterSelectView(size: size, selectedClass: selectedCharacterClass) { [weak self] selectedClass in
            self?.selectedCharacterClass = selectedClass
            self?.updateCharacterPreview()
            // Don't auto-close - let user browse and close manually
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

        // Hide entire main menu including title
        menuContainer.isHidden = true
        titleContainer.isHidden = true
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
        titleContainer.isHidden = false
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
