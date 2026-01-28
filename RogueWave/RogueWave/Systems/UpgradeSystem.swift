//
//  UpgradeSystem.swift
//  RogueWave
//
//  Manages upgrade selection, application, and synergies
//

import SpriteKit

// MARK: - Upgrade Structure

struct Upgrade: Codable, Equatable {
    let type: UpgradeType
    var level: Int

    var displayName: String {
        return type.displayName
    }

    var description: String {
        if level > 1 {
            return "\(type.description) (Lv.\(level))"
        }
        return type.description
    }

    var color: SKColor {
        return type.color
    }

    static func == (lhs: Upgrade, rhs: Upgrade) -> Bool {
        return lhs.type == rhs.type && lhs.level == rhs.level
    }
}

// MARK: - Upgrade Rarity

enum UpgradeRarity: Int, CaseIterable {
    case common = 0
    case uncommon = 1
    case rare = 2
    case epic = 3
    case legendary = 4

    var color: SKColor {
        switch self {
        case .common: return SKColor.white
        case .uncommon: return SKColor.green
        case .rare: return SKColor.blue
        case .epic: return SKColor.purple
        case .legendary: return SKColor.orange
        }
    }

    var dropWeight: Int {
        switch self {
        case .common: return 50
        case .uncommon: return 30
        case .rare: return 15
        case .epic: return 4
        case .legendary: return 1
        }
    }
}

// MARK: - Upgrade Pool Configuration

struct UpgradePoolConfig {
    // Base upgrades available from wave 1
    static let wave1Upgrades: [UpgradeType] = [
        .maxHealth,
        .moveSpeed,
        .damage,
        .attackSpeed,
        .critChance
    ]

    // Unlocked at wave 3
    static let wave3Upgrades: [UpgradeType] = [
        .attackRange,
        .projectileSpeed,
        .dash
    ]

    // Unlocked at wave 5
    static let wave5Upgrades: [UpgradeType] = [
        .critDamage,
        .armor,
        .lifeSteal,
        .multishot
    ]

    // Unlocked at wave 7
    static let wave7Upgrades: [UpgradeType] = [
        .aoeBlast,
        .shield,
        .piercing,
        .homing
    ]
}

// MARK: - Upgrade System Class

class UpgradeSystem {

    // MARK: - Properties

    // Current run upgrades
    private(set) var acquiredUpgrades: [UpgradeType: Int] = [:]

    // Build synergies tracking
    private(set) var activeSynergies: [BuildSynergy] = []

    // Available pool based on wave
    private var availablePool: [UpgradeType] = []

    // MARK: - Initialization

    init() {
        resetForNewRun()
    }

    // MARK: - Pool Management

    func updateAvailablePool(forWave wave: Int) {
        availablePool = UpgradePoolConfig.wave1Upgrades

        if wave >= 3 {
            availablePool.append(contentsOf: UpgradePoolConfig.wave3Upgrades)
        }
        if wave >= 5 {
            availablePool.append(contentsOf: UpgradePoolConfig.wave5Upgrades)
        }
        if wave >= 7 {
            availablePool.append(contentsOf: UpgradePoolConfig.wave7Upgrades)
        }
    }

    // MARK: - Upgrade Selection

    func generateUpgradeChoices(count: Int = UpgradeConfig.choicesPerUpgrade) -> [Upgrade] {
        var choices: [Upgrade] = []
        var usedTypes: Set<UpgradeType> = []

        // Filter available upgrades (exclude maxed out)
        let eligibleTypes = availablePool.filter { type in
            let currentLevel = acquiredUpgrades[type] ?? 0
            // Active abilities can only be acquired once
            if type.isActive && currentLevel > 0 {
                return false
            }
            return currentLevel < UpgradeConfig.maxUpgradeLevel
        }

        // Select random upgrades
        var attempts = 0
        while choices.count < count && attempts < 50 {
            attempts += 1

            guard let randomType = eligibleTypes.randomElement(),
                  !usedTypes.contains(randomType) else { continue }

            usedTypes.insert(randomType)

            let currentLevel = acquiredUpgrades[randomType] ?? 0
            let upgrade = Upgrade(type: randomType, level: currentLevel + 1)
            choices.append(upgrade)
        }

        // If we couldn't find enough unique upgrades, fill with any available
        if choices.count < count {
            for type in eligibleTypes {
                if choices.count >= count { break }
                if usedTypes.contains(type) { continue }

                let currentLevel = acquiredUpgrades[type] ?? 0
                let upgrade = Upgrade(type: type, level: currentLevel + 1)
                choices.append(upgrade)
                usedTypes.insert(type)
            }
        }

        return choices
    }

    // MARK: - Upgrade Application

    func acquireUpgrade(_ upgrade: Upgrade) {
        acquiredUpgrades[upgrade.type] = upgrade.level

        // Check for new synergies
        checkSynergies()
    }

    func getUpgradeLevel(for type: UpgradeType) -> Int {
        return acquiredUpgrades[type] ?? 0
    }

    func hasUpgrade(_ type: UpgradeType) -> Bool {
        return (acquiredUpgrades[type] ?? 0) > 0
    }

    // MARK: - Synergy System

    private func checkSynergies() {
        activeSynergies.removeAll()

        // Check each possible synergy
        for synergy in BuildSynergy.allSynergies {
            if synergy.isActive(with: acquiredUpgrades) {
                activeSynergies.append(synergy)
            }
        }
    }

    func getSynergyBonuses() -> SynergyBonuses {
        var bonuses = SynergyBonuses()

        for synergy in activeSynergies {
            synergy.applyBonus(to: &bonuses)
        }

        return bonuses
    }

    // MARK: - Reset

    func resetForNewRun() {
        acquiredUpgrades.removeAll()
        activeSynergies.removeAll()
        availablePool = UpgradePoolConfig.wave1Upgrades
    }

    // MARK: - Debug/Info

    func getAcquiredUpgradesList() -> [Upgrade] {
        return acquiredUpgrades.map { Upgrade(type: $0.key, level: $0.value) }
            .sorted { $0.type.rawValue < $1.type.rawValue }
    }
}

// MARK: - Build Synergies

struct SynergyBonuses {
    var damageMultiplier: CGFloat = 1.0
    var speedMultiplier: CGFloat = 1.0
    var healthMultiplier: CGFloat = 1.0
    var critChanceBonus: CGFloat = 0
    var cooldownReduction: CGFloat = 0
}

struct BuildSynergy {
    let name: String
    let description: String
    let requiredUpgrades: [UpgradeType]
    let bonusEffect: (inout SynergyBonuses) -> Void

    func isActive(with upgrades: [UpgradeType: Int]) -> Bool {
        return requiredUpgrades.allSatisfy { (upgrades[$0] ?? 0) > 0 }
    }

    func applyBonus(to bonuses: inout SynergyBonuses) {
        bonusEffect(&bonuses)
    }

    // Predefined synergies
    static let allSynergies: [BuildSynergy] = [
        // Glass Cannon: High damage, low survivability
        BuildSynergy(
            name: "Glass Cannon",
            description: "+30% damage",
            requiredUpgrades: [.damage, .critChance, .critDamage],
            bonusEffect: { $0.damageMultiplier += 0.3 }
        ),

        // Speedster: Fast movement and attacks
        BuildSynergy(
            name: "Speedster",
            description: "+20% speed, +15% attack speed",
            requiredUpgrades: [.moveSpeed, .attackSpeed, .dash],
            bonusEffect: {
                $0.speedMultiplier += 0.2
                $0.cooldownReduction += 0.15
            }
        ),

        // Tank: High survivability
        BuildSynergy(
            name: "Tank",
            description: "+25% health",
            requiredUpgrades: [.maxHealth, .armor, .shield],
            bonusEffect: { $0.healthMultiplier += 0.25 }
        ),

        // Gunslinger: Projectile specialist
        BuildSynergy(
            name: "Gunslinger",
            description: "+10% crit chance",
            requiredUpgrades: [.multishot, .projectileSpeed, .attackSpeed],
            bonusEffect: { $0.critChanceBonus += 0.1 }
        ),

        // Vampire: Life steal build
        BuildSynergy(
            name: "Vampire",
            description: "+15% damage, +10% health",
            requiredUpgrades: [.lifeSteal, .damage, .attackSpeed],
            bonusEffect: {
                $0.damageMultiplier += 0.15
                $0.healthMultiplier += 0.1
            }
        )
    ]
}

// MARK: - Upgrade Card Visual Data

struct UpgradeCardData {
    let upgrade: Upgrade
    let rarity: UpgradeRarity

    var iconName: String {
        // Map upgrade types to icon names (could use SF Symbols or custom icons)
        switch upgrade.type {
        case .maxHealth: return "heart.fill"
        case .moveSpeed: return "figure.run"
        case .damage: return "bolt.fill"
        case .attackSpeed: return "timer"
        case .critChance: return "star.fill"
        case .critDamage: return "star.circle.fill"
        case .attackRange: return "scope"
        case .projectileSpeed: return "arrow.right"
        case .armor: return "shield.fill"
        case .lifeSteal: return "drop.fill"
        case .dash: return "wind"
        case .aoeBlast: return "burst.fill"
        case .shield: return "shield.lefthalf.filled"
        case .multishot: return "arrow.triangle.branch"
        case .piercing: return "arrow.right.arrow.left"
        case .homing: return "target"
        }
    }

    static func determineRarity(for upgrade: Upgrade) -> UpgradeRarity {
        // Active abilities are rarer
        if upgrade.type.isActive {
            return upgrade.level == 1 ? .rare : .epic
        }

        // Higher levels are rarer
        switch upgrade.level {
        case 1: return .common
        case 2: return .uncommon
        case 3: return .rare
        case 4: return .epic
        case 5: return .legendary
        default: return .common
        }
    }
}
