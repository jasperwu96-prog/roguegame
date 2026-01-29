//
//  MenuViews.swift
//  RogueWave
//
//  Submenu views for the main menu
//

import SpriteKit

// MARK: - Base Submenu View

class SubMenuView: SKNode {

    let viewSize: CGSize
    private let background: SKShapeNode
    private let titleLabel: SKLabelNode
    private let closeButton: SKShapeNode
    var contentNode: SKNode?

    init(size: CGSize, title: String) {
        self.viewSize = size

        // Semi-transparent background
        background = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: size.height - 120), cornerRadius: 20)
        background.fillColor = SKColor(red: 0.08, green: 0.1, blue: 0.15, alpha: 0.95)
        background.strokeColor = SKColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
        background.lineWidth = 2

        // Title
        titleLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        titleLabel.text = title
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white

        // Close button
        closeButton = SKShapeNode(circleOfRadius: 18)
        closeButton.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.8)
        closeButton.strokeColor = .white
        closeButton.lineWidth = 2
        closeButton.name = "closeButton"

        super.init()

        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(background)

        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 90)
        addChild(titleLabel)

        closeButton.position = CGPoint(x: size.width - 45, y: size.height - 85)
        addChild(closeButton)

        let xLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        xLabel.text = "X"
        xLabel.fontSize = 18
        xLabel.fontColor = .white
        xLabel.verticalAlignmentMode = .center
        xLabel.horizontalAlignmentMode = .center
        closeButton.addChild(xLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func createScrollableContent() -> SKNode {
        let content = SKNode()
        content.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2 - 30)
        addChild(content)
        contentNode = content
        return content
    }

    // Override in subclasses to handle specific touches
    func handleTouch(at location: CGPoint) -> Bool {
        return false
    }
}

// MARK: - Stats View

class StatsView: SubMenuView {

    init(size: CGSize) {
        super.init(size: size, title: "STATISTICS")

        let content = createScrollableContent()
        let stats = GameManager.shared
        let lineHeight: CGFloat = 35

        let statsData: [(String, String)] = [
            ("Total Runs", "\(stats.metaProgression.totalRuns)"),
            ("Best Wave", "\(stats.metaProgression.highestWave)"),
            ("Total Kills", "\(stats.metaProgression.totalKills)"),
            ("Total Gold", "\(stats.metaProgression.totalGold)"),
            ("Best Kills (Run)", "\(stats.currentRunStats.enemiesKilled)"),
            ("Total Damage Dealt", "\(Int(stats.currentRunStats.damageDealt))"),
            ("Total Time Played", formatTime(stats.currentRunStats.timeSurvived)),
            ("Abilities Used", "\(stats.currentRunStats.abilitiesUsed)"),
            ("Critical Hits", "\(stats.currentRunStats.criticalHits)"),
        ]

        for (index, (label, value)) in statsData.enumerated() {
            let y = CGFloat(statsData.count / 2 - index) * lineHeight

            let labelNode = SKLabelNode(fontNamed: UIConfig.fontName)
            labelNode.text = label
            labelNode.fontSize = 16
            labelNode.fontColor = SKColor(white: 0.7, alpha: 1.0)
            labelNode.horizontalAlignmentMode = .left
            labelNode.position = CGPoint(x: -130, y: y)
            content.addChild(labelNode)

            let valueNode = SKLabelNode(fontNamed: UIConfig.fontName)
            valueNode.text = value
            valueNode.fontSize = 16
            valueNode.fontColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
            valueNode.horizontalAlignmentMode = .right
            valueNode.position = CGPoint(x: 130, y: y)
            content.addChild(valueNode)

            // Separator line
            if index < statsData.count - 1 {
                let line = SKShapeNode(rectOf: CGSize(width: 260, height: 1))
                line.fillColor = SKColor(white: 0.2, alpha: 1.0)
                line.strokeColor = .clear
                line.position = CGPoint(x: 0, y: y - lineHeight / 2)
                content.addChild(line)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Achievements View

class AchievementsView: SubMenuView {

    private var scrollContainer: SKNode?
    private var lastDragY: CGFloat = 0
    private var velocity: CGFloat = 0
    private var isDecelerating: Bool = false
    private var contentHeight: CGFloat = 0
    private var visibleHeight: CGFloat = 0

    init(size: CGSize) {
        super.init(size: size, title: "ACHIEVEMENTS")

        let content = createScrollableContent()
        visibleHeight = size.height - 200  // Visible area for scrolling

        // Progress header (fixed, not scrolling) - add FIRST so it's behind
        let headerBg = SKShapeNode(rectOf: CGSize(width: 300, height: 70))
        headerBg.fillColor = SKColor(red: 0.08, green: 0.1, blue: 0.15, alpha: 1.0)
        headerBg.strokeColor = .clear
        headerBg.position = CGPoint(x: 0, y: visibleHeight / 2 - 35)
        headerBg.zPosition = 10  // Above scroll content
        content.addChild(headerBg)

        let progress = AchievementManager.shared.getProgress()
        let progressLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        progressLabel.text = "\(progress.unlocked) / \(progress.total) Unlocked"
        progressLabel.fontSize = 16
        progressLabel.fontColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        progressLabel.position = CGPoint(x: 0, y: visibleHeight / 2 - 20)
        progressLabel.zPosition = 11
        content.addChild(progressLabel)

        // Progress bar
        let barWidth: CGFloat = 200
        let barBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: 8), cornerRadius: 4)
        barBg.fillColor = SKColor(white: 0.15, alpha: 1.0)
        barBg.strokeColor = .clear
        barBg.position = CGPoint(x: 0, y: visibleHeight / 2 - 45)
        barBg.zPosition = 11
        content.addChild(barBg)

        let progressRatio = progress.total > 0 ? CGFloat(progress.unlocked) / CGFloat(progress.total) : 0
        let fillWidth = max(barWidth * progressRatio, 8)
        let barFill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 6), cornerRadius: 3)
        barFill.fillColor = SKColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        barFill.strokeColor = .clear
        barFill.position = CGPoint(x: (fillWidth - barWidth) / 2, y: visibleHeight / 2 - 45)
        barFill.zPosition = 12
        content.addChild(barFill)

        // Create a crop node to clip the scrolling content
        let scrollClipHeight = visibleHeight - 90  // Leave room for header
        let cropNode = SKCropNode()
        cropNode.position = CGPoint(x: 0, y: -25)  // Offset down from header
        content.addChild(cropNode)

        // Mask shape for cropping
        let maskNode = SKShapeNode(rectOf: CGSize(width: 300, height: scrollClipHeight))
        maskNode.fillColor = .white
        maskNode.strokeColor = .clear
        cropNode.maskNode = maskNode

        // Create scroll container for achievements inside the crop node
        let scrollNode = SKNode()
        scrollNode.name = "scrollContainer"
        cropNode.addChild(scrollNode)
        scrollContainer = scrollNode

        // Display achievements in scrollable list
        let achievements = AchievementManager.shared.getAllAchievements()
        let itemWidth: CGFloat = 280
        let itemHeight: CGFloat = 70
        let spacing: CGFloat = 12
        let startY: CGFloat = scrollClipHeight / 2 - 40  // Start near top of scroll area

        var visibleIndex = 0
        for achievement in achievements {
            // Skip hidden locked achievements
            if achievement.isHidden && !achievement.isUnlocked {
                continue
            }

            let y = startY - CGFloat(visibleIndex) * (itemHeight + spacing)
            let card = createAchievementCard(achievement, width: itemWidth, height: itemHeight)
            card.position = CGPoint(x: 0, y: y)
            scrollNode.addChild(card)

            visibleIndex += 1
        }

        // Calculate total content height
        contentHeight = CGFloat(visibleIndex) * (itemHeight + spacing)

        // Add scroll hint if content is scrollable
        if contentHeight > scrollClipHeight {
            let hint = SKLabelNode(fontNamed: UIConfig.fontName)
            hint.text = "↕ Swipe to scroll"
            hint.fontSize = 11
            hint.fontColor = SKColor(white: 0.4, alpha: 1.0)
            hint.position = CGPoint(x: 0, y: -visibleHeight / 2 + 10)
            hint.zPosition = 10
            content.addChild(hint)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func handleDragBegan(at location: CGPoint) {
        isDecelerating = false
        scrollContainer?.removeAction(forKey: "decelerate")
        lastDragY = location.y
        velocity = 0
    }

    func handleDragMoved(to location: CGPoint) {
        guard let container = scrollContainer else { return }

        let deltaY = location.y - lastDragY
        velocity = deltaY
        lastDragY = location.y

        // Calculate scroll bounds
        let maxScrollUp = contentHeight - visibleHeight + 100  // How far we can scroll up
        let minY: CGFloat = 0  // Starting position
        let maxY: CGFloat = max(0, maxScrollUp)  // Can scroll up this much

        var newY = container.position.y - deltaY  // Invert: drag up = content goes down

        // Rubber band effect at edges
        if newY < minY {
            let overscroll = minY - newY
            newY = minY - overscroll * 0.3
        } else if newY > maxY {
            let overscroll = newY - maxY
            newY = maxY + overscroll * 0.3
        }

        container.position.y = newY
    }

    func handleDragEnded() {
        guard let container = scrollContainer else { return }

        let maxScrollUp = contentHeight - visibleHeight + 100
        let minY: CGFloat = 0
        let maxY: CGFloat = max(0, maxScrollUp)

        isDecelerating = true
        applyMomentum(velocity: -velocity, minY: minY, maxY: maxY)
    }

    private func applyMomentum(velocity: CGFloat, minY: CGFloat, maxY: CGFloat) {
        guard let container = scrollContainer, isDecelerating else { return }

        let friction: CGFloat = 0.95
        var currentVelocity = velocity

        let decelerateAction = SKAction.customAction(withDuration: 2.0) { [weak self] _, _ in
            guard let self = self, self.isDecelerating else { return }

            currentVelocity *= friction

            var newY = container.position.y + currentVelocity

            // Bounce back from edges
            if newY < minY {
                newY = minY
                self.isDecelerating = false
            } else if newY > maxY {
                newY = maxY
                self.isDecelerating = false
            }

            container.position.y = newY

            if abs(currentVelocity) < 0.5 {
                self.isDecelerating = false
            }
        }

        container.run(decelerateAction, withKey: "decelerate")
    }

    private func createAchievementCard(_ achievement: Achievement, width: CGFloat, height: CGFloat) -> SKNode {
        let card = SKNode()

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        bg.fillColor = achievement.isUnlocked ?
            SKColor(red: 0.12, green: 0.22, blue: 0.12, alpha: 1.0) :
            SKColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        bg.strokeColor = achievement.isUnlocked ?
            SKColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) :
            SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        bg.lineWidth = achievement.isUnlocked ? 2 : 1
        if achievement.isUnlocked {
            bg.glowWidth = 2
        }
        card.addChild(bg)

        // Icon circle background
        let iconBg = SKShapeNode(circleOfRadius: 22)
        iconBg.fillColor = achievement.isUnlocked ?
            SKColor(red: 0.25, green: 0.4, blue: 0.25, alpha: 1.0) :
            SKColor(white: 0.15, alpha: 1.0)
        iconBg.strokeColor = achievement.isUnlocked ?
            SKColor(red: 0.4, green: 0.6, blue: 0.4, alpha: 1.0) :
            SKColor(white: 0.25, alpha: 1.0)
        iconBg.lineWidth = 1
        iconBg.position = CGPoint(x: -width / 2 + 35, y: 0)
        card.addChild(iconBg)

        // Trophy/Lock icon
        let icon = SKLabelNode(fontNamed: UIConfig.fontName)
        icon.text = achievement.isUnlocked ? "🏆" : "🔒"
        icon.fontSize = 22
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: -width / 2 + 35, y: 0)
        card.addChild(icon)

        // Text content area starts after the icon
        let textStartX: CGFloat = -width / 2 + 70
        let textWidth: CGFloat = width - 90

        // Name
        let name = SKLabelNode(fontNamed: UIConfig.fontName)
        name.text = achievement.isUnlocked ? achievement.name : "???"
        name.fontSize = 14
        name.fontColor = achievement.isUnlocked ? .white : SKColor(white: 0.5, alpha: 1.0)
        name.horizontalAlignmentMode = .left
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: textStartX, y: 12)
        card.addChild(name)

        // Description
        let desc = SKLabelNode(fontNamed: UIConfig.fontName)
        desc.text = achievement.isUnlocked ? achievement.description : "Complete hidden requirement"
        desc.fontSize = 11
        desc.fontColor = SKColor(white: 0.55, alpha: 1.0)
        desc.horizontalAlignmentMode = .left
        desc.verticalAlignmentMode = .center
        desc.preferredMaxLayoutWidth = textWidth
        desc.numberOfLines = 2
        desc.position = CGPoint(x: textStartX, y: -10)
        card.addChild(desc)

        return card
    }
}

// MARK: - Character Select View

enum CharacterClass: String, CaseIterable {
    case knight = "Knight"
    case rogue = "Rogue"
    case mage = "Mage"
    case berserker = "Berserker"

    var description: String {
        switch self {
        case .knight: return "Balanced stats, starts with Shield ability"
        case .rogue: return "+30% Speed, +20% Crit, lower HP"
        case .mage: return "Powerful abilities, faster cooldowns"
        case .berserker: return "+50% Damage, no armor, life steal"
        }
    }

    var color: SKColor {
        switch self {
        case .knight: return SKColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)
        case .rogue: return SKColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0)
        case .mage: return SKColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0)
        case .berserker: return SKColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0)
        }
    }

    var isUnlocked: Bool {
        switch self {
        case .knight: return true
        case .rogue: return GameManager.shared.metaProgression.highestWave >= 5
        case .mage: return GameManager.shared.metaProgression.highestWave >= 10
        case .berserker: return GameManager.shared.metaProgression.highestWave >= 15
        }
    }

    var unlockRequirement: String {
        switch self {
        case .knight: return "Starting character"
        case .rogue: return "Reach Wave 5"
        case .mage: return "Reach Wave 10"
        case .berserker: return "Reach Wave 15"
        }
    }
}

class CharacterSelectView: SubMenuView {

    var onSelect: ((CharacterClass) -> Void)?
    private var selectedClass: CharacterClass
    private let cardWidth: CGFloat = 130
    private let cardHeight: CGFloat = 180
    private let spacing: CGFloat = 15
    private var cardsContainer: SKNode?

    // Scroll tracking
    private var lastDragX: CGFloat = 0
    private var velocity: CGFloat = 0
    private var isDecelerating: Bool = false

    init(size: CGSize, selectedClass: CharacterClass, onSelect: @escaping (CharacterClass) -> Void) {
        self.selectedClass = selectedClass
        self.onSelect = onSelect
        super.init(size: size, title: "SELECT CHARACTER")

        let content = createScrollableContent()

        // Create a container for scrollable cards
        let container = SKNode()
        container.name = "cardsContainer"
        content.addChild(container)
        cardsContainer = container

        rebuildCards(in: container)

        // Add hint
        let hint = SKLabelNode(fontNamed: UIConfig.fontName)
        hint.text = "← Swipe to browse →"
        hint.fontSize = 12
        hint.fontColor = SKColor(white: 0.5, alpha: 1.0)
        hint.position = CGPoint(x: 0, y: -cardHeight / 2 - 40)
        content.addChild(hint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuildCards(in container: SKNode, preservePosition: Bool = false) {
        let currentX = container.position.x

        // Remove existing cards
        container.removeAllChildren()

        for (index, charClass) in CharacterClass.allCases.enumerated() {
            let x = CGFloat(index) * (cardWidth + spacing)
            let card = createCharacterCard(charClass, width: cardWidth, height: cardHeight, isSelected: charClass == selectedClass)
            card.position = CGPoint(x: x, y: 0)
            card.name = charClass.rawValue
            container.addChild(card)
        }

        // Preserve position if requested, otherwise reset to 0
        container.position.x = preservePosition ? currentX : 0
    }

    override func handleTouch(at location: CGPoint) -> Bool {
        guard let content = contentNode, let container = cardsContainer else { return false }

        let contentLocation = content.convert(location, from: self)
        let containerLocation = container.convert(contentLocation, from: content)

        // Check each character card
        for charClass in CharacterClass.allCases {
            if let card = container.childNode(withName: charClass.rawValue) {
                let cardLocation = card.convert(containerLocation, from: container)

                // Check if touch is within card bounds
                if abs(cardLocation.x) < cardWidth / 2 && abs(cardLocation.y) < cardHeight / 2 {
                    // Only select if unlocked and not already selected
                    if charClass.isUnlocked && charClass != selectedClass {
                        selectedClass = charClass
                        rebuildCards(in: container, preservePosition: true)
                        onSelect?(charClass)
                        return true
                    }
                }
            }
        }

        return false
    }

    func handleDragBegan(at location: CGPoint) {
        isDecelerating = false
        cardsContainer?.removeAction(forKey: "decelerate")
        lastDragX = location.x
        velocity = 0
    }

    func handleDragMoved(to location: CGPoint) {
        guard let container = cardsContainer else { return }

        let deltaX = location.x - lastDragX
        velocity = deltaX  // Track velocity for momentum
        lastDragX = location.x

        // Calculate scroll bounds
        // minX: show last card centered (container moved left)
        // maxX: show first card centered (container at 0)
        let numCards = CGFloat(CharacterClass.allCases.count)
        let minX = -((numCards - 1) * (cardWidth + spacing))
        let maxX: CGFloat = 0

        var newX = container.position.x + deltaX

        // Add rubber band effect at edges
        if newX > maxX {
            let overscroll = newX - maxX
            newX = maxX + overscroll * 0.3
        } else if newX < minX {
            let overscroll = minX - newX
            newX = minX - overscroll * 0.3
        }

        container.position.x = newX
    }

    func handleDragEnded() {
        guard let container = cardsContainer else { return }

        // Calculate scroll bounds
        let numCards = CGFloat(CharacterClass.allCases.count)
        let minX = -((numCards - 1) * (cardWidth + spacing))
        let maxX: CGFloat = 0

        // Apply momentum scrolling
        isDecelerating = true
        applyMomentum(velocity: velocity, minX: minX, maxX: maxX)
    }

    private func applyMomentum(velocity: CGFloat, minX: CGFloat, maxX: CGFloat) {
        guard let container = cardsContainer, isDecelerating else { return }

        let friction: CGFloat = 0.95
        var currentVelocity = velocity

        let decelerateAction = SKAction.customAction(withDuration: 2.0) { [weak self] node, elapsed in
            guard let self = self, self.isDecelerating else { return }

            currentVelocity *= friction

            var newX = container.position.x + currentVelocity

            // Bounce back from edges
            if newX > maxX {
                newX = maxX
                self.isDecelerating = false
            } else if newX < minX {
                newX = minX
                self.isDecelerating = false
            }

            container.position.x = newX

            // Stop when velocity is very low
            if abs(currentVelocity) < 0.5 {
                self.isDecelerating = false
            }
        }

        container.run(decelerateAction, withKey: "decelerate")
    }

    private func createCharacterCard(_ charClass: CharacterClass, width: CGFloat, height: CGFloat, isSelected: Bool) -> SKNode {
        let card = SKNode()
        let isUnlocked = charClass.isUnlocked

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 12)
        bg.fillColor = isUnlocked ?
            (isSelected ? charClass.color.withAlphaComponent(0.3) : SKColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)) :
            SKColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        bg.strokeColor = isSelected ? charClass.color : SKColor(white: 0.2, alpha: 1.0)
        bg.lineWidth = isSelected ? 3 : 1
        if isSelected { bg.glowWidth = 5 }
        card.addChild(bg)

        // Character portrait
        let iconContainer = SKNode()
        iconContainer.position = CGPoint(x: 0, y: height / 2 - 50)
        card.addChild(iconContainer)

        if isUnlocked {
            createCharacterPortrait(for: charClass, in: iconContainer, scale: 0.7)
        } else {
            // Locked character - show silhouette with lock
            let silhouette = SKShapeNode(circleOfRadius: 30)
            silhouette.fillColor = SKColor(white: 0.15, alpha: 1.0)
            silhouette.strokeColor = SKColor(white: 0.25, alpha: 1.0)
            silhouette.lineWidth = 2
            iconContainer.addChild(silhouette)

            let lock = SKLabelNode(fontNamed: UIConfig.fontName)
            lock.text = "🔒"
            lock.fontSize = 24
            lock.verticalAlignmentMode = .center
            silhouette.addChild(lock)
        }

        // Name
        let name = SKLabelNode(fontNamed: UIConfig.fontName)
        name.text = charClass.rawValue
        name.fontSize = 16
        name.fontColor = isUnlocked ? .white : SKColor(white: 0.4, alpha: 1.0)
        name.position = CGPoint(x: 0, y: height / 2 - 100)
        card.addChild(name)

        // Description
        let desc = SKLabelNode(fontNamed: UIConfig.fontName)
        desc.text = isUnlocked ? charClass.description : charClass.unlockRequirement
        desc.fontSize = 9
        desc.fontColor = SKColor(white: 0.5, alpha: 1.0)
        desc.preferredMaxLayoutWidth = width - 20
        desc.numberOfLines = 3
        desc.position = CGPoint(x: 0, y: height / 2 - 130)
        card.addChild(desc)

        // Select button or Selected label
        if isUnlocked && !isSelected {
            let selectBtn = SKShapeNode(rectOf: CGSize(width: 80, height: 25), cornerRadius: 12)
            selectBtn.fillColor = charClass.color
            selectBtn.strokeColor = .clear
            selectBtn.position = CGPoint(x: 0, y: -height / 2 + 25)
            selectBtn.name = "selectBtn_\(charClass.rawValue)"
            card.addChild(selectBtn)

            let selectLabel = SKLabelNode(fontNamed: UIConfig.fontName)
            selectLabel.text = "SELECT"
            selectLabel.fontSize = 11
            selectLabel.fontColor = .white
            selectLabel.verticalAlignmentMode = .center
            selectBtn.addChild(selectLabel)
        } else if isSelected {
            let selectedLabel = SKLabelNode(fontNamed: UIConfig.fontName)
            selectedLabel.text = "SELECTED"
            selectedLabel.fontSize = 11
            selectedLabel.fontColor = charClass.color
            selectedLabel.position = CGPoint(x: 0, y: -height / 2 + 25)
            card.addChild(selectedLabel)
        }

        return card
    }

    private func createCharacterPortrait(for charClass: CharacterClass, in container: SKNode, scale: CGFloat) {
        let s: CGFloat = 40 * scale  // Base size

        switch charClass {
        case .knight:
            // Knight helmet
            let helmet = SKShapeNode(circleOfRadius: s * 0.8)
            helmet.fillColor = SKColor(red: 0.75, green: 0.75, blue: 0.8, alpha: 1.0)
            helmet.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
            helmet.lineWidth = 2
            container.addChild(helmet)

            // Visor
            let visor = SKShapeNode(rectOf: CGSize(width: s * 0.8, height: s * 0.15))
            visor.fillColor = SKColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0)
            visor.strokeColor = .clear
            visor.position = CGPoint(x: 0, y: s * 0.1)
            helmet.addChild(visor)

            // Plume
            let plume = SKShapeNode(rectOf: CGSize(width: s * 0.15, height: s * 0.5))
            plume.fillColor = SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)
            plume.strokeColor = .clear
            plume.position = CGPoint(x: 0, y: s * 0.6)
            helmet.addChild(plume)

            // Glowing eyes
            for xOffset in [-s * 0.2, s * 0.2] {
                let eye = SKShapeNode(circleOfRadius: s * 0.08)
                eye.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 3
                eye.position = CGPoint(x: xOffset, y: s * 0.1)
                helmet.addChild(eye)
            }

        case .rogue:
            // Hood
            let hood = SKShapeNode(circleOfRadius: s * 0.8)
            hood.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.2, alpha: 1.0)
            hood.strokeColor = SKColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)
            hood.lineWidth = 2
            container.addChild(hood)

            // Hood point
            let pointPath = CGMutablePath()
            pointPath.move(to: CGPoint(x: -s * 0.3, y: s * 0.4))
            pointPath.addLine(to: CGPoint(x: 0, y: s * 0.9))
            pointPath.addLine(to: CGPoint(x: s * 0.3, y: s * 0.4))
            pointPath.closeSubpath()
            let point = SKShapeNode(path: pointPath)
            point.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.2, alpha: 1.0)
            point.strokeColor = .clear
            hood.addChild(point)

            // Shadowed face
            let face = SKShapeNode(circleOfRadius: s * 0.4)
            face.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)
            face.strokeColor = .clear
            face.position = CGPoint(x: 0, y: -s * 0.1)
            hood.addChild(face)

            // Green glowing eyes
            for xOffset in [-s * 0.15, s * 0.15] {
                let eye = SKShapeNode(circleOfRadius: s * 0.08)
                eye.fillColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 4
                eye.position = CGPoint(x: xOffset, y: -s * 0.05)
                hood.addChild(eye)
            }

        case .mage:
            // Face
            let face = SKShapeNode(circleOfRadius: s * 0.5)
            face.fillColor = SKColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1.0)
            face.strokeColor = .clear
            face.position = CGPoint(x: 0, y: -s * 0.15)
            container.addChild(face)

            // Beard
            let beard = SKShapeNode(ellipseOf: CGSize(width: s * 0.5, height: s * 0.4))
            beard.fillColor = SKColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
            beard.strokeColor = .clear
            beard.position = CGPoint(x: 0, y: -s * 0.5)
            face.addChild(beard)

            // Wizard hat
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

            // Hat brim
            let brim = SKShapeNode(ellipseOf: CGSize(width: s * 1.4, height: s * 0.3))
            brim.fillColor = SKColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 1.0)
            brim.strokeColor = SKColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1.0)
            brim.lineWidth = 2
            brim.position = CGPoint(x: 0, y: s * 0.25)
            container.addChild(brim)

            // Purple glowing eyes
            for xOffset in [-s * 0.15, s * 0.15] {
                let eye = SKShapeNode(circleOfRadius: s * 0.07)
                eye.fillColor = SKColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 4
                eye.position = CGPoint(x: xOffset, y: -s * 0.1)
                face.addChild(eye)
            }

        case .berserker:
            // Face
            let face = SKShapeNode(circleOfRadius: s * 0.7)
            face.fillColor = SKColor(red: 0.85, green: 0.65, blue: 0.5, alpha: 1.0)
            face.strokeColor = SKColor(red: 0.7, green: 0.5, blue: 0.35, alpha: 1.0)
            face.lineWidth = 2
            container.addChild(face)

            // War paint
            let paint = SKShapeNode(rectOf: CGSize(width: s * 1.0, height: s * 0.1))
            paint.fillColor = SKColor(red: 0.8, green: 0.15, blue: 0.1, alpha: 1.0)
            paint.strokeColor = .clear
            paint.position = CGPoint(x: 0, y: s * 0.05)
            face.addChild(paint)

            let paint2 = SKShapeNode(rectOf: CGSize(width: s * 0.8, height: s * 0.08))
            paint2.fillColor = SKColor(red: 0.8, green: 0.15, blue: 0.1, alpha: 1.0)
            paint2.strokeColor = .clear
            paint2.position = CGPoint(x: 0, y: -s * 0.15)
            face.addChild(paint2)

            // Mohawk
            let mohawkPath = CGMutablePath()
            mohawkPath.move(to: CGPoint(x: -s * 0.15, y: s * 0.5))
            mohawkPath.addLine(to: CGPoint(x: 0, y: s * 1.1))
            mohawkPath.addLine(to: CGPoint(x: s * 0.15, y: s * 0.5))
            mohawkPath.closeSubpath()
            let mohawk = SKShapeNode(path: mohawkPath)
            mohawk.fillColor = SKColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)
            mohawk.strokeColor = .clear
            face.addChild(mohawk)

            // Angry red eyes
            for xOffset in [-s * 0.2, s * 0.2] {
                let eye = SKShapeNode(circleOfRadius: s * 0.1)
                eye.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0)
                eye.strokeColor = .clear
                eye.glowWidth = 5
                eye.position = CGPoint(x: xOffset, y: s * 0.1)
                face.addChild(eye)
            }
        }
    }
}

// MARK: - Upgrades View

class UpgradesView: SubMenuView {

    private var goldLabel: SKLabelNode?
    private var upgradeRows: [PermanentUpgrade: SKNode] = [:]

    init(size: CGSize) {
        super.init(size: size, title: "META UPGRADES")

        let content = createScrollableContent()

        let itemHeight: CGFloat = 70
        let upgrades = PermanentUpgrade.allCases
        let startY: CGFloat = CGFloat(upgrades.count) / 2 * itemHeight - 20

        for (index, upgrade) in upgrades.enumerated() {
            let y = startY - CGFloat(index) * itemHeight
            let row = createUpgradeRow(for: upgrade)
            row.position = CGPoint(x: 0, y: y)
            row.name = upgrade.rawValue
            content.addChild(row)
            upgradeRows[upgrade] = row
        }

        // Gold display
        let goldBg = SKShapeNode(rectOf: CGSize(width: 140, height: 35), cornerRadius: 17)
        goldBg.fillColor = SKColor(red: 0.15, green: 0.12, blue: 0.05, alpha: 1.0)
        goldBg.strokeColor = SKColor(red: 0.6, green: 0.5, blue: 0.2, alpha: 1.0)
        goldBg.lineWidth = 2
        goldBg.position = CGPoint(x: 0, y: -startY - 60)
        content.addChild(goldBg)

        let gold = SKLabelNode(fontNamed: UIConfig.fontName)
        gold.text = "💰 \(GameManager.shared.metaProgression.totalGold)"
        gold.fontSize = 16
        gold.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        gold.verticalAlignmentMode = .center
        gold.position = CGPoint(x: 0, y: -startY - 60)
        content.addChild(gold)
        goldLabel = gold

        // Tap hint
        let hint = SKLabelNode(fontNamed: UIConfig.fontName)
        hint.text = "Tap upgrade to purchase"
        hint.fontSize = 11
        hint.fontColor = SKColor(white: 0.4, alpha: 1.0)
        hint.position = CGPoint(x: 0, y: -startY - 95)
        content.addChild(hint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func handleTouch(at location: CGPoint) -> Bool {
        guard let content = contentNode else { return false }

        let contentLocation = content.convert(location, from: self)

        // Check each upgrade row
        for upgrade in PermanentUpgrade.allCases {
            if let row = upgradeRows[upgrade] {
                let rowLocation = row.convert(contentLocation, from: content)
                if abs(rowLocation.x) < 140 && abs(rowLocation.y) < 35 {
                    return attemptPurchase(upgrade)
                }
            }
        }

        return false
    }

    private func attemptPurchase(_ upgrade: PermanentUpgrade) -> Bool {
        if GameManager.shared.purchaseUpgrade(upgrade) {
            // Success - update display
            refreshUpgradeRow(upgrade)
            goldLabel?.text = "💰 \(GameManager.shared.metaProgression.totalGold)"

            // Visual feedback
            if let row = upgradeRows[upgrade] {
                let flash = SKAction.sequence([
                    SKAction.run { row.alpha = 0.5 },
                    SKAction.wait(forDuration: 0.1),
                    SKAction.run { row.alpha = 1.0 }
                ])
                row.run(flash)
            }

            // Refresh all rows to update affordability
            for otherUpgrade in PermanentUpgrade.allCases {
                refreshUpgradeRow(otherUpgrade)
            }

            return true
        }
        return false
    }

    private func refreshUpgradeRow(_ upgrade: PermanentUpgrade) {
        guard let row = upgradeRows[upgrade], let content = contentNode else { return }
        let position = row.position
        row.removeFromParent()

        let newRow = createUpgradeRow(for: upgrade)
        newRow.position = position
        newRow.name = upgrade.rawValue
        content.addChild(newRow)
        upgradeRows[upgrade] = newRow
    }

    private func createUpgradeRow(for upgrade: PermanentUpgrade) -> SKNode {
        let row = SKNode()
        let level = GameManager.shared.getUpgradeLevel(upgrade)
        let maxLevel = upgrade.maxLevel
        let isMaxed = level >= maxLevel
        let canAfford = GameManager.shared.canAffordUpgrade(upgrade)
        let cost = isMaxed ? 0 : upgrade.cost(forLevel: level)

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 65), cornerRadius: 10)
        if isMaxed {
            bg.fillColor = SKColor(red: 0.1, green: 0.15, blue: 0.1, alpha: 1.0)
            bg.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
        } else if canAfford {
            bg.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
            bg.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)
        } else {
            bg.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
            bg.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        }
        bg.lineWidth = canAfford && !isMaxed ? 2 : 1
        row.addChild(bg)

        // Name
        let nameLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        nameLabel.text = upgrade.displayName
        nameLabel.fontSize = 14
        nameLabel.fontColor = isMaxed ? SKColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 1.0) : .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -125, y: 12)
        row.addChild(nameLabel)

        // Description
        let descLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        descLabel.text = upgrade.description
        descLabel.fontSize = 10
        descLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        descLabel.horizontalAlignmentMode = .left
        descLabel.position = CGPoint(x: -125, y: -5)
        row.addChild(descLabel)

        // Cost or MAX label
        let costLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        if isMaxed {
            costLabel.text = "MAX"
            costLabel.fontColor = SKColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 1.0)
        } else {
            costLabel.text = "💰 \(cost)"
            costLabel.fontColor = canAfford ?
                SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0) :
                SKColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0)
        }
        costLabel.fontSize = 12
        costLabel.horizontalAlignmentMode = .left
        costLabel.position = CGPoint(x: -125, y: -22)
        row.addChild(costLabel)

        // Level pips on right side
        let pipSpacing: CGFloat = 12
        let pipSize: CGFloat = 6
        let totalPipWidth = CGFloat(maxLevel - 1) * pipSpacing
        let startX: CGFloat = 125 - totalPipWidth

        for i in 0..<maxLevel {
            let pip = SKShapeNode(circleOfRadius: pipSize)
            pip.fillColor = i < level ?
                SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0) :
                SKColor(white: 0.15, alpha: 1.0)
            pip.strokeColor = i < level ?
                SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) :
                SKColor(white: 0.3, alpha: 1.0)
            pip.lineWidth = 1
            pip.position = CGPoint(x: startX + CGFloat(i) * pipSpacing, y: 0)
            if i < level { pip.glowWidth = 2 }
            row.addChild(pip)
        }

        // Level text
        let levelLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        levelLabel.text = "\(level)/\(maxLevel)"
        levelLabel.fontSize = 10
        levelLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        levelLabel.horizontalAlignmentMode = .right
        levelLabel.position = CGPoint(x: 125, y: -22)
        row.addChild(levelLabel)

        return row
    }
}

// MARK: - Challenges View

class ChallengesView: SubMenuView {

    init(size: CGSize) {
        super.init(size: size, title: "CHALLENGES")

        let content = createScrollableContent()

        // Coming soon message
        let comingSoon = SKLabelNode(fontNamed: UIConfig.fontName)
        comingSoon.text = "🚧 COMING SOON 🚧"
        comingSoon.fontSize = 20
        comingSoon.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
        comingSoon.position = CGPoint(x: 0, y: 120)
        content.addChild(comingSoon)

        let desc = SKLabelNode(fontNamed: UIConfig.fontName)
        desc.text = "Daily and weekly challenges\nwill be added in a future update!"
        desc.fontSize = 14
        desc.fontColor = SKColor(white: 0.6, alpha: 1.0)
        desc.numberOfLines = 2
        desc.position = CGPoint(x: 0, y: 80)
        content.addChild(desc)

        // Show current goals based on stats
        let goalsTitle = SKLabelNode(fontNamed: UIConfig.fontName)
        goalsTitle.text = "Current Goals"
        goalsTitle.fontSize = 16
        goalsTitle.fontColor = .white
        goalsTitle.position = CGPoint(x: 0, y: 30)
        content.addChild(goalsTitle)

        let stats = GameManager.shared.metaProgression

        // Goal 1: Reach wave 10
        let goal1Progress = min(stats.highestWave, 10)
        let goal1Card = createGoalCard(
            title: "Wave Master",
            description: "Reach Wave 10",
            progress: "\(goal1Progress)/10",
            progressRatio: CGFloat(goal1Progress) / 10.0,
            color: SKColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0),
            isComplete: goal1Progress >= 10
        )
        goal1Card.position = CGPoint(x: 0, y: -30)
        content.addChild(goal1Card)

        // Goal 2: Kill 100 enemies total
        let goal2Progress = min(stats.totalKills, 100)
        let goal2Card = createGoalCard(
            title: "Hunter",
            description: "Kill 100 enemies total",
            progress: "\(goal2Progress)/100",
            progressRatio: CGFloat(goal2Progress) / 100.0,
            color: SKColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 1.0),
            isComplete: goal2Progress >= 100
        )
        goal2Card.position = CGPoint(x: 0, y: -110)
        content.addChild(goal2Card)

        // Goal 3: Complete 5 runs
        let goal3Progress = min(stats.totalRuns, 5)
        let goal3Card = createGoalCard(
            title: "Persistent",
            description: "Complete 5 runs",
            progress: "\(goal3Progress)/5",
            progressRatio: CGFloat(goal3Progress) / 5.0,
            color: SKColor(red: 0.5, green: 0.5, blue: 0.8, alpha: 1.0),
            isComplete: goal3Progress >= 5
        )
        goal3Card.position = CGPoint(x: 0, y: -190)
        content.addChild(goal3Card)
    }

    private func createGoalCard(title: String, description: String, progress: String, progressRatio: CGFloat, color: SKColor, isComplete: Bool) -> SKNode {
        let card = SKNode()

        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 65), cornerRadius: 10)
        bg.fillColor = isComplete ? color.withAlphaComponent(0.25) : SKColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
        bg.strokeColor = isComplete ? color : SKColor(white: 0.2, alpha: 1.0)
        bg.lineWidth = isComplete ? 2 : 1
        if isComplete { bg.glowWidth = 3 }
        card.addChild(bg)

        // Title
        let titleLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        titleLabel.text = isComplete ? "✓ \(title)" : title
        titleLabel.fontSize = 14
        titleLabel.fontColor = isComplete ? color : .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -125, y: 12)
        card.addChild(titleLabel)

        // Description
        let descLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        descLabel.text = description
        descLabel.fontSize = 10
        descLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        descLabel.horizontalAlignmentMode = .left
        descLabel.position = CGPoint(x: -125, y: -5)
        card.addChild(descLabel)

        // Progress bar
        let barWidth: CGFloat = 100
        let barBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: 8), cornerRadius: 4)
        barBg.fillColor = SKColor(white: 0.15, alpha: 1.0)
        barBg.strokeColor = .clear
        barBg.position = CGPoint(x: 75, y: -18)
        card.addChild(barBg)

        let fillWidth = max(barWidth * progressRatio, 4)
        let barFill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 6), cornerRadius: 3)
        barFill.fillColor = color
        barFill.strokeColor = .clear
        barFill.position = CGPoint(x: 75 + (fillWidth - barWidth) / 2, y: -18)
        card.addChild(barFill)

        // Progress text
        let progressLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        progressLabel.text = progress
        progressLabel.fontSize = 10
        progressLabel.fontColor = color
        progressLabel.horizontalAlignmentMode = .right
        progressLabel.position = CGPoint(x: 125, y: 8)
        card.addChild(progressLabel)

        return card
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Settings View

class SettingsView: SubMenuView {

    private var musicEnabled: Bool = true
    private var sfxEnabled: Bool = true
    private var hapticsEnabled: Bool = true
    private var screenShakeEnabled: Bool = true

    init(size: CGSize) {
        super.init(size: size, title: "SETTINGS")

        musicEnabled = AudioManager.shared.musicEnabled
        sfxEnabled = AudioManager.shared.sfxEnabled
        hapticsEnabled = AudioManager.shared.hapticsEnabled
        screenShakeEnabled = GameManager.shared.screenShakeEnabled

        let content = createScrollableContent()

        // Music toggle
        let musicRow = createToggleRow(
            label: "Music",
            isOn: musicEnabled,
            y: 80
        )
        musicRow.name = "musicToggle"
        content.addChild(musicRow)

        // SFX toggle
        let sfxRow = createToggleRow(
            label: "Sound Effects",
            isOn: sfxEnabled,
            y: 30
        )
        sfxRow.name = "sfxToggle"
        content.addChild(sfxRow)

        // Haptics toggle
        let hapticsRow = createToggleRow(
            label: "Haptic Feedback",
            isOn: hapticsEnabled,
            y: -20
        )
        hapticsRow.name = "hapticsToggle"
        content.addChild(hapticsRow)

        // Screen shake toggle
        let shakeRow = createToggleRow(
            label: "Screen Shake",
            isOn: screenShakeEnabled,
            y: -70
        )
        shakeRow.name = "shakeToggle"
        content.addChild(shakeRow)

        // Credits
        let creditsLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        creditsLabel.text = "Made with ❤️ by Claude"
        creditsLabel.fontSize = 12
        creditsLabel.fontColor = SKColor(white: 0.4, alpha: 1.0)
        creditsLabel.position = CGPoint(x: 0, y: -150)
        content.addChild(creditsLabel)

        // Reset progress button
        let resetBtn = SKShapeNode(rectOf: CGSize(width: 150, height: 35), cornerRadius: 8)
        resetBtn.fillColor = SKColor(red: 0.6, green: 0.15, blue: 0.15, alpha: 1.0)
        resetBtn.strokeColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        resetBtn.lineWidth = 1
        resetBtn.position = CGPoint(x: 0, y: -200)
        resetBtn.name = "resetButton"
        content.addChild(resetBtn)

        let resetLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        resetLabel.text = "Reset Progress"
        resetLabel.fontSize = 13
        resetLabel.fontColor = .white
        resetLabel.verticalAlignmentMode = .center
        resetBtn.addChild(resetLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func handleTouch(at location: CGPoint) -> Bool {
        guard let content = contentNode else { return false }
        let contentLocation = content.convert(location, from: self)

        // Check toggle rows
        let toggles: [(String, CGFloat)] = [
            ("musicToggle", 80),
            ("sfxToggle", 30),
            ("hapticsToggle", -20),
            ("shakeToggle", -70)
        ]

        for (name, y) in toggles {
            // Check if touch is in toggle area (right side where toggle switch is)
            if contentLocation.x > 50 && contentLocation.x < 150 &&
               contentLocation.y > y - 20 && contentLocation.y < y + 20 {
                toggleSetting(name)
                return true
            }
        }

        // Check reset button
        if let resetBtn = content.childNode(withName: "resetButton") as? SKShapeNode {
            let resetLocation = resetBtn.convert(contentLocation, from: content)
            if resetBtn.contains(resetLocation) {
                resetProgress()
                return true
            }
        }

        return false
    }

    private func toggleSetting(_ name: String) {
        guard let content = contentNode,
              let row = content.childNode(withName: name) else { return }

        // Find the toggle background (SKShapeNode at position x: 100)
        for child in row.children {
            if let toggleBg = child as? SKShapeNode,
               toggleBg.position.x == 100 {
                // Get current state and toggle
                var isOn: Bool
                switch name {
                case "musicToggle":
                    musicEnabled.toggle()
                    isOn = musicEnabled
                    AudioManager.shared.musicEnabled = isOn
                    if isOn {
                        AudioManager.shared.playBackgroundMusic()
                    } else {
                        AudioManager.shared.stopBackgroundMusic()
                    }
                case "sfxToggle":
                    sfxEnabled.toggle()
                    isOn = sfxEnabled
                    AudioManager.shared.sfxEnabled = isOn
                case "hapticsToggle":
                    hapticsEnabled.toggle()
                    isOn = hapticsEnabled
                    AudioManager.shared.hapticsEnabled = isOn
                case "shakeToggle":
                    screenShakeEnabled.toggle()
                    isOn = screenShakeEnabled
                    GameManager.shared.screenShakeEnabled = isOn
                default:
                    return
                }

                // Update visual
                toggleBg.fillColor = isOn ?
                    SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0) :
                    SKColor(white: 0.25, alpha: 1.0)

                // Animate knob
                if let knob = toggleBg.children.first as? SKShapeNode {
                    let moveAction = SKAction.moveTo(x: isOn ? 12 : -12, duration: 0.15)
                    moveAction.timingMode = .easeOut
                    knob.run(moveAction)
                }
                break
            }
        }
    }

    private func resetProgress() {
        // Flash the button
        guard let content = contentNode,
              let resetBtn = content.childNode(withName: "resetButton") as? SKShapeNode else { return }

        let flash = SKAction.sequence([
            SKAction.run { resetBtn.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { resetBtn.fillColor = SKColor(red: 0.6, green: 0.15, blue: 0.15, alpha: 1.0) }
        ])
        resetBtn.run(flash)

        // Reset game progress
        GameManager.shared.resetAllProgress()
        AchievementManager.shared.resetProgress()

        // Show confirmation
        let confirmLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        confirmLabel.text = "Progress Reset!"
        confirmLabel.fontSize = 14
        confirmLabel.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)
        confirmLabel.position = CGPoint(x: 0, y: -235)
        content.addChild(confirmLabel)

        confirmLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    private func createToggleRow(label: String, isOn: Bool, y: CGFloat) -> SKNode {
        let row = SKNode()
        row.position = CGPoint(x: 0, y: y)

        let labelNode = SKLabelNode(fontNamed: UIConfig.fontName)
        labelNode.text = label
        labelNode.fontSize = 16
        labelNode.fontColor = .white
        labelNode.horizontalAlignmentMode = .left
        labelNode.position = CGPoint(x: -120, y: -5)
        row.addChild(labelNode)

        // Toggle switch
        let toggleBg = SKShapeNode(rectOf: CGSize(width: 50, height: 26), cornerRadius: 13)
        toggleBg.fillColor = isOn ?
            SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0) :
            SKColor(white: 0.25, alpha: 1.0)
        toggleBg.strokeColor = .clear
        toggleBg.position = CGPoint(x: 100, y: 0)
        row.addChild(toggleBg)

        let toggleKnob = SKShapeNode(circleOfRadius: 10)
        toggleKnob.fillColor = .white
        toggleKnob.strokeColor = .clear
        toggleKnob.position = CGPoint(x: isOn ? 12 : -12, y: 0)
        toggleKnob.name = "knob"
        toggleBg.addChild(toggleKnob)

        return row
    }
}
