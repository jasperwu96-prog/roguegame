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
        return content
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

    init(size: CGSize) {
        super.init(size: size, title: "ACHIEVEMENTS")

        let content = createScrollableContent()

        let progress = AchievementManager.shared.getProgress()
        let progressLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        progressLabel.text = "\(progress.unlocked) / \(progress.total) Unlocked"
        progressLabel.fontSize = 14
        progressLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        progressLabel.position = CGPoint(x: 0, y: 200)
        content.addChild(progressLabel)

        // Display achievements in a grid
        let achievements = AchievementManager.shared.getAllAchievements()
        let columns = 2
        let itemWidth: CGFloat = 140
        let itemHeight: CGFloat = 60
        let spacing: CGFloat = 10

        for (index, achievement) in achievements.enumerated() {
            // Skip hidden locked achievements
            if achievement.isHidden && !achievement.isUnlocked {
                continue
            }

            let col = index % columns
            let row = index / columns
            let x = CGFloat(col) * (itemWidth + spacing) - (itemWidth + spacing) / 2
            let y = 150 - CGFloat(row) * (itemHeight + spacing)

            let card = createAchievementCard(achievement, width: itemWidth, height: itemHeight)
            card.position = CGPoint(x: x, y: y)
            content.addChild(card)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createAchievementCard(_ achievement: Achievement, width: CGFloat, height: CGFloat) -> SKNode {
        let card = SKNode()

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        bg.fillColor = achievement.isUnlocked ?
            SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0) :
            SKColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        bg.strokeColor = achievement.isUnlocked ?
            SKColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0) :
            SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        bg.lineWidth = 1
        card.addChild(bg)

        // Trophy icon
        let icon = SKLabelNode(fontNamed: UIConfig.fontName)
        icon.text = achievement.isUnlocked ? "🏆" : "🔒"
        icon.fontSize = 20
        icon.position = CGPoint(x: -width / 2 + 20, y: -5)
        card.addChild(icon)

        // Name
        let name = SKLabelNode(fontNamed: UIConfig.fontName)
        name.text = achievement.isUnlocked ? achievement.name : "???"
        name.fontSize = 11
        name.fontColor = achievement.isUnlocked ? .white : SKColor(white: 0.5, alpha: 1.0)
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -width / 2 + 40, y: 8)
        card.addChild(name)

        // Description
        let desc = SKLabelNode(fontNamed: UIConfig.fontName)
        desc.text = achievement.isUnlocked ? achievement.description : "Hidden"
        desc.fontSize = 9
        desc.fontColor = SKColor(white: 0.5, alpha: 1.0)
        desc.horizontalAlignmentMode = .left
        desc.position = CGPoint(x: -width / 2 + 40, y: -8)
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

    init(size: CGSize, selectedClass: CharacterClass, onSelect: @escaping (CharacterClass) -> Void) {
        self.selectedClass = selectedClass
        self.onSelect = onSelect
        super.init(size: size, title: "SELECT CHARACTER")

        let content = createScrollableContent()

        let cardWidth: CGFloat = 130
        let cardHeight: CGFloat = 180
        let spacing: CGFloat = 15

        for (index, charClass) in CharacterClass.allCases.enumerated() {
            let x = CGFloat(index - CharacterClass.allCases.count / 2) * (cardWidth + spacing) + (cardWidth + spacing) / 2
            let card = createCharacterCard(charClass, width: cardWidth, height: cardHeight, isSelected: charClass == selectedClass)
            card.position = CGPoint(x: x, y: 0)
            card.name = charClass.rawValue
            content.addChild(card)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        // Character icon placeholder
        let icon = SKShapeNode(circleOfRadius: 30)
        icon.fillColor = isUnlocked ? charClass.color : SKColor(white: 0.2, alpha: 1.0)
        icon.strokeColor = isUnlocked ? charClass.color.withAlphaComponent(0.8) : SKColor(white: 0.3, alpha: 1.0)
        icon.lineWidth = 2
        icon.position = CGPoint(x: 0, y: height / 2 - 50)
        card.addChild(icon)

        if !isUnlocked {
            let lock = SKLabelNode(fontNamed: UIConfig.fontName)
            lock.text = "🔒"
            lock.fontSize = 24
            lock.verticalAlignmentMode = .center
            icon.addChild(lock)
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

        // Select button
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
}

// MARK: - Upgrades View

class UpgradesView: SubMenuView {

    init(size: CGSize) {
        super.init(size: size, title: "META UPGRADES")

        let content = createScrollableContent()

        let upgrades: [(String, String, Int, Int)] = [
            ("Starting Health", "+10% Max HP per level", 1, 5),
            ("Starting Damage", "+5% Damage per level", 0, 5),
            ("Starting Speed", "+5% Speed per level", 0, 5),
            ("XP Bonus", "+10% XP gain per level", 2, 5),
            ("Gold Bonus", "+15% Gold per level", 0, 5),
            ("Extra Reroll", "+1 Upgrade reroll per level", 1, 3),
        ]

        let itemHeight: CGFloat = 55
        let startY: CGFloat = CGFloat(upgrades.count) / 2 * itemHeight

        for (index, (name, desc, level, maxLevel)) in upgrades.enumerated() {
            let y = startY - CGFloat(index) * itemHeight

            let row = createUpgradeRow(name: name, description: desc, level: level, maxLevel: maxLevel)
            row.position = CGPoint(x: 0, y: y)
            content.addChild(row)
        }

        // Gold display
        let goldLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        goldLabel.text = "Gold: \(GameManager.shared.metaProgression.totalGold)"
        goldLabel.fontSize = 16
        goldLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        goldLabel.position = CGPoint(x: 0, y: -startY - 50)
        content.addChild(goldLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createUpgradeRow(name: String, description: String, level: Int, maxLevel: Int) -> SKNode {
        let row = SKNode()

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 50), cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
        bg.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        bg.lineWidth = 1
        row.addChild(bg)

        // Name
        let nameLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        nameLabel.text = name
        nameLabel.fontSize = 14
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -130, y: 8)
        row.addChild(nameLabel)

        // Description
        let descLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        descLabel.text = description
        descLabel.fontSize = 10
        descLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        descLabel.horizontalAlignmentMode = .left
        descLabel.position = CGPoint(x: -130, y: -8)
        row.addChild(descLabel)

        // Level pips
        for i in 0..<maxLevel {
            let pip = SKShapeNode(circleOfRadius: 6)
            pip.fillColor = i < level ?
                SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0) :
                SKColor(white: 0.2, alpha: 1.0)
            pip.strokeColor = SKColor(white: 0.4, alpha: 1.0)
            pip.lineWidth = 1
            pip.position = CGPoint(x: 100 + CGFloat(i) * 16, y: 0)
            row.addChild(pip)
        }

        return row
    }
}

// MARK: - Challenges View

class ChallengesView: SubMenuView {

    init(size: CGSize) {
        super.init(size: size, title: "DAILY CHALLENGES")

        let content = createScrollableContent()

        // Daily challenge
        let dailyCard = createChallengeCard(
            title: "Daily Challenge",
            description: "Survive 5 waves using only the Dash ability",
            reward: "500 Gold",
            progress: "2/5 Waves",
            timeRemaining: "12:34:56",
            color: SKColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0)
        )
        dailyCard.position = CGPoint(x: 0, y: 80)
        content.addChild(dailyCard)

        // Weekly challenge
        let weeklyCard = createChallengeCard(
            title: "Weekly Challenge",
            description: "Kill 500 enemies without taking damage in a single wave",
            reward: "Legendary Skin",
            progress: "312/500 Kills",
            timeRemaining: "5d 12:34:56",
            color: SKColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0)
        )
        weeklyCard.position = CGPoint(x: 0, y: -80)
        content.addChild(weeklyCard)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createChallengeCard(title: String, description: String, reward: String, progress: String, timeRemaining: String, color: SKColor) -> SKNode {
        let card = SKNode()

        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 120), cornerRadius: 12)
        bg.fillColor = color.withAlphaComponent(0.15)
        bg.strokeColor = color
        bg.lineWidth = 2
        card.addChild(bg)

        // Title
        let titleLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        titleLabel.text = title
        titleLabel.fontSize = 16
        titleLabel.fontColor = color
        titleLabel.position = CGPoint(x: 0, y: 40)
        card.addChild(titleLabel)

        // Description
        let descLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        descLabel.text = description
        descLabel.fontSize = 11
        descLabel.fontColor = .white
        descLabel.preferredMaxLayoutWidth = 250
        descLabel.numberOfLines = 2
        descLabel.position = CGPoint(x: 0, y: 15)
        card.addChild(descLabel)

        // Progress bar
        let progressBg = SKShapeNode(rectOf: CGSize(width: 200, height: 12), cornerRadius: 6)
        progressBg.fillColor = SKColor(white: 0.15, alpha: 1.0)
        progressBg.strokeColor = .clear
        progressBg.position = CGPoint(x: 0, y: -15)
        card.addChild(progressBg)

        let progressFill = SKShapeNode(rectOf: CGSize(width: 120, height: 10), cornerRadius: 5)
        progressFill.fillColor = color
        progressFill.strokeColor = .clear
        progressFill.position = CGPoint(x: -40, y: -15)
        card.addChild(progressFill)

        // Progress text
        let progressLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        progressLabel.text = progress
        progressLabel.fontSize = 10
        progressLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        progressLabel.position = CGPoint(x: 120, y: -18)
        card.addChild(progressLabel)

        // Reward
        let rewardLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        rewardLabel.text = "Reward: \(reward)"
        rewardLabel.fontSize = 11
        rewardLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        rewardLabel.position = CGPoint(x: -70, y: -42)
        rewardLabel.horizontalAlignmentMode = .left
        card.addChild(rewardLabel)

        // Time remaining
        let timeLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        timeLabel.text = timeRemaining
        timeLabel.fontSize = 10
        timeLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        timeLabel.position = CGPoint(x: 100, y: -42)
        card.addChild(timeLabel)

        return card
    }
}

// MARK: - Settings View

class SettingsView: SubMenuView {

    init(size: CGSize) {
        super.init(size: size, title: "SETTINGS")

        let content = createScrollableContent()

        // Music toggle
        let musicRow = createToggleRow(
            label: "Music",
            isOn: AudioManager.shared.musicEnabled,
            y: 80
        )
        musicRow.name = "musicToggle"
        content.addChild(musicRow)

        // SFX toggle
        let sfxRow = createToggleRow(
            label: "Sound Effects",
            isOn: AudioManager.shared.sfxEnabled,
            y: 30
        )
        sfxRow.name = "sfxToggle"
        content.addChild(sfxRow)

        // Haptics toggle
        let hapticsRow = createToggleRow(
            label: "Haptic Feedback",
            isOn: true,
            y: -20
        )
        content.addChild(hapticsRow)

        // Screen shake toggle
        let shakeRow = createToggleRow(
            label: "Screen Shake",
            isOn: true,
            y: -70
        )
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
        toggleBg.addChild(toggleKnob)

        return row
    }
}
