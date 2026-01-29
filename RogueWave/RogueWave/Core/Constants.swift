//
//  Constants.swift
//  RogueWave
//
//  Game-wide constants and configuration values
//

import SpriteKit

// MARK: - Game Configuration

enum GameConfig {
    // Frame rate target
    static let targetFPS: Int = 60

    // Arena boundaries (relative to screen)
    static let arenaPadding: CGFloat = 50

    // Z-Position layers for rendering order
    enum ZPosition {
        static let background: CGFloat = 0
        static let floor: CGFloat = 1
        static let enemy: CGFloat = 10
        static let projectile: CGFloat = 15
        static let player: CGFloat = 20
        static let effects: CGFloat = 25
        static let ui: CGFloat = 100
        static let overlay: CGFloat = 200
    }

    // Physics categories for collision detection
    enum PhysicsCategory {
        static let none: UInt32 = 0
        static let player: UInt32 = 0x1 << 0        // 1
        static let enemy: UInt32 = 0x1 << 1         // 2
        static let playerProjectile: UInt32 = 0x1 << 2  // 4
        static let enemyProjectile: UInt32 = 0x1 << 3   // 8
        static let pickup: UInt32 = 0x1 << 4        // 16
        static let boundary: UInt32 = 0x1 << 5      // 32
    }
}

// MARK: - Player Configuration

enum PlayerConfig {
    // Base stats
    static let baseHealth: CGFloat = 100
    static let baseSpeed: CGFloat = 200
    static let baseDamage: CGFloat = 10
    static let baseAttackSpeed: CGFloat = 1.0  // attacks per second
    static let baseAttackRange: CGFloat = 400  // Increased for open world
    static let baseProjectileSpeed: CGFloat = 500  // Faster projectiles
    static let baseCritChance: CGFloat = 0.05
    static let baseCritMultiplier: CGFloat = 2.0

    // Visual
    static let size: CGFloat = 40
    static let color: SKColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
    static let hitFlashDuration: TimeInterval = 0.1
    static let invincibilityDuration: TimeInterval = 0.5

    // Experience
    static let baseXPToLevel: Int = 100
    static let xpScalingFactor: CGFloat = 1.5
}

// MARK: - Enemy Configuration

enum EnemyConfig {
    // Spawn settings
    static let spawnPadding: CGFloat = 50  // Distance from screen edge
    static let maxEnemiesOnScreen: Int = 50
    static let spawnInterval: TimeInterval = 0.5

    // Base scaling per wave
    static let healthScalingPerWave: CGFloat = 1.15
    static let damageScalingPerWave: CGFloat = 1.1
    static let speedScalingPerWave: CGFloat = 1.02

    // Enemy type configurations
    enum Chaser {
        static let baseHealth: CGFloat = 20
        static let baseSpeed: CGFloat = 100
        static let baseDamage: CGFloat = 10
        static let size: CGFloat = 30
        static let color: SKColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        static let xpValue: Int = 10
    }

    enum Swarm {
        static let baseHealth: CGFloat = 10
        static let baseSpeed: CGFloat = 150
        static let baseDamage: CGFloat = 5
        static let size: CGFloat = 20
        static let color: SKColor = SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)
        static let xpValue: Int = 5
    }

    enum Ranged {
        static let baseHealth: CGFloat = 15
        static let baseSpeed: CGFloat = 60
        static let baseDamage: CGFloat = 15
        static let size: CGFloat = 28
        static let color: SKColor = SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)
        static let attackRange: CGFloat = 250
        static let projectileSpeed: CGFloat = 300
        static let attackCooldown: TimeInterval = 2.0
        static let xpValue: Int = 15
    }

    enum Tank {
        static let baseHealth: CGFloat = 80
        static let baseSpeed: CGFloat = 50
        static let baseDamage: CGFloat = 25
        static let size: CGFloat = 50
        static let color: SKColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        static let xpValue: Int = 30
    }

    enum Elite {
        static let healthMultiplier: CGFloat = 3.0
        static let damageMultiplier: CGFloat = 1.5
        static let sizeMultiplier: CGFloat = 1.5
        static let glowColor: SKColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.8)
        static let xpMultiplier: Int = 5
    }

    enum Boss {
        static let healthMultiplier: CGFloat = 10.0
        static let damageMultiplier: CGFloat = 2.0
        static let sizeMultiplier: CGFloat = 2.5
        static let color: SKColor = SKColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 1.0)
        static let xpMultiplier: Int = 20
    }
}

// MARK: - Wave Configuration

enum WaveConfig {
    // Timing
    static let waveDuration: TimeInterval = 30.0
    static let breakDuration: TimeInterval = 5.0
    static let bossWaveInterval: Int = 5

    // Difficulty scaling
    static let baseEnemyCount: Int = 5
    static let enemyCountScaling: CGFloat = 1.2
    static let eliteChancePerWave: CGFloat = 0.02

    // Wave modifiers
    static let modifierChance: CGFloat = 0.3

    // First 3 waves spawn configuration
    static let wave1Enemies: [(EnemyType, Int)] = [(.chaser, 5)]
    static let wave2Enemies: [(EnemyType, Int)] = [(.chaser, 6), (.swarm, 4)]
    static let wave3Enemies: [(EnemyType, Int)] = [(.chaser, 5), (.swarm, 6), (.ranged, 2)]
}

// MARK: - Upgrade Configuration

enum UpgradeConfig {
    static let choicesPerUpgrade: Int = 3
    static let maxUpgradeLevel: Int = 5

    // Passive upgrade values
    enum PassiveValues {
        static let healthBonus: CGFloat = 20
        static let speedBonus: CGFloat = 20
        static let damageBonus: CGFloat = 5
        static let attackSpeedBonus: CGFloat = 0.15
        static let critChanceBonus: CGFloat = 0.05
        static let critDamageBonus: CGFloat = 0.25
        static let rangeBonus: CGFloat = 30
        static let projectileSpeedBonus: CGFloat = 50
    }

    // Active ability cooldowns
    enum AbilityCooldowns {
        static let dash: TimeInterval = 3.0
        static let aoe: TimeInterval = 8.0
        static let shield: TimeInterval = 15.0
        static let multishot: TimeInterval = 0  // passive
    }
}

// MARK: - UI Configuration

enum UIConfig {
    // Colors
    static let backgroundColor: SKColor = SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
    static let healthBarBackground: SKColor = SKColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 1.0)
    static let healthBarForeground: SKColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
    static let xpBarBackground: SKColor = SKColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
    static let xpBarForeground: SKColor = SKColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)

    // Sizes
    static let healthBarWidth: CGFloat = 200
    static let healthBarHeight: CGFloat = 20
    static let xpBarWidth: CGFloat = 300
    static let xpBarHeight: CGFloat = 10

    // Joystick
    static let joystickBaseSize: CGFloat = 120
    static let joystickKnobSize: CGFloat = 60
    static let joystickAlpha: CGFloat = 0.6
    static let joystickPosition: CGPoint = CGPoint(x: 100, y: 150)

    // Fonts
    static let titleFontSize: CGFloat = 32
    static let bodyFontSize: CGFloat = 18
    static let smallFontSize: CGFloat = 14
    static let fontName: String = "AvenirNext-Bold"
}

// MARK: - Persistence Keys

enum PersistenceKeys {
    static let totalGold = "totalGold"
    static let highestWave = "highestWave"
    static let totalKills = "totalKills"
    static let totalRuns = "totalRuns"
    static let unlockedUpgrades = "unlockedUpgrades"
    static let permanentUpgrades = "permanentUpgrades"
}

// MARK: - Enemy Types

enum EnemyType: String, CaseIterable, Codable {
    case chaser
    case swarm
    case ranged
    case tank
    case elite
    case boss
}

// MARK: - Upgrade Types

enum UpgradeType: String, CaseIterable, Codable {
    // Passive upgrades
    case maxHealth
    case moveSpeed
    case damage
    case attackSpeed
    case critChance
    case critDamage
    case attackRange
    case projectileSpeed
    case armor
    case lifeSteal

    // Active abilities
    case dash
    case aoeBlast
    case shield
    case multishot
    case piercing
    case homing

    var isActive: Bool {
        switch self {
        case .dash, .aoeBlast, .shield:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .maxHealth: return "Max Health"
        case .moveSpeed: return "Move Speed"
        case .damage: return "Damage"
        case .attackSpeed: return "Attack Speed"
        case .critChance: return "Crit Chance"
        case .critDamage: return "Crit Damage"
        case .attackRange: return "Attack Range"
        case .projectileSpeed: return "Projectile Speed"
        case .armor: return "Armor"
        case .lifeSteal: return "Life Steal"
        case .dash: return "Dash"
        case .aoeBlast: return "AOE Blast"
        case .shield: return "Shield"
        case .multishot: return "Multishot"
        case .piercing: return "Piercing"
        case .homing: return "Homing"
        }
    }

    var description: String {
        switch self {
        case .maxHealth: return "+20 Max HP"
        case .moveSpeed: return "+10% Move Speed"
        case .damage: return "+5 Damage"
        case .attackSpeed: return "+15% Attack Speed"
        case .critChance: return "+5% Crit Chance"
        case .critDamage: return "+25% Crit Damage"
        case .attackRange: return "+30 Range"
        case .projectileSpeed: return "+50 Proj Speed"
        case .armor: return "+5 Armor"
        case .lifeSteal: return "+3% Life Steal"
        case .dash: return "Quick dash ability"
        case .aoeBlast: return "Area damage blast"
        case .shield: return "Temporary shield"
        case .multishot: return "+1 Projectile"
        case .piercing: return "Projectiles pierce"
        case .homing: return "Seeking projectiles"
        }
    }

    var color: SKColor {
        switch self {
        case .maxHealth: return SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        case .moveSpeed: return SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        case .damage: return SKColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0)
        case .attackSpeed: return SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0)
        case .critChance, .critDamage: return SKColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)
        case .attackRange, .projectileSpeed: return SKColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0)
        case .armor: return SKColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1.0)
        case .lifeSteal: return SKColor(red: 0.7, green: 0.2, blue: 0.4, alpha: 1.0)
        case .dash, .aoeBlast, .shield: return SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        case .multishot, .piercing, .homing: return SKColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        }
    }
}

// MARK: - Wave Modifiers

enum WaveModifier: String, CaseIterable {
    case speedBoost      // Enemies move faster
    case healthBoost     // Enemies have more health
    case damageBoost     // Enemies deal more damage
    case swarm           // More enemies spawn
    case elite           // Higher elite spawn chance
    case regen           // Enemies regenerate health

    var displayName: String {
        switch self {
        case .speedBoost: return "Swift Enemies"
        case .healthBoost: return "Fortified"
        case .damageBoost: return "Enraged"
        case .swarm: return "Swarm"
        case .elite: return "Elite Wave"
        case .regen: return "Regenerating"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .speedBoost: return 1.3
        case .healthBoost: return 1.5
        case .damageBoost: return 1.4
        case .swarm: return 1.5
        case .elite: return 2.0
        case .regen: return 1.0
        }
    }
}

// MARK: - Game State

enum GameState {
    case menu
    case playing
    case paused
    case waveComplete
    case upgradeSelection
    case gameOver
}
