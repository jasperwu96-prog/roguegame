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
    // Base stats - Skill-based gameplay!
    static let baseHealth: CGFloat = 100  // Lower HP - dodge to survive!
    static let baseSpeed: CGFloat = 300  // Faster movement for dodging
    static let baseDamage: CGFloat = 25  // Hits harder
    static let baseAttackSpeed: CGFloat = 3.0  // 3 attacks per second
    static let baseAttackRange: CGFloat = 600  // Long range
    static let baseProjectileSpeed: CGFloat = 700  // Fast projectiles
    static let baseCritChance: CGFloat = 0.15  // More crits
    static let baseCritMultiplier: CGFloat = 2.5  // Bigger crits

    // Visual
    static let size: CGFloat = 40
    static let color: SKColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
    static let hitFlashDuration: TimeInterval = 0.1
    static let invincibilityDuration: TimeInterval = 0.5  // Short invincibility - dodge instead!

    // Experience - faster leveling for more upgrades
    static let baseXPToLevel: Int = 50
    static let xpScalingFactor: CGFloat = 1.3
}

// MARK: - Enemy Configuration

enum EnemyConfig {
    // Spawn settings - Fast action!
    static let spawnPadding: CGFloat = 30  // Distance outside spawn bounds
    static let maxEnemiesOnScreen: Int = 80  // More enemies on screen
    static let spawnInterval: TimeInterval = 0.15  // Very fast spawning

    // Base scaling per wave
    static let healthScalingPerWave: CGFloat = 1.15
    static let damageScalingPerWave: CGFloat = 1.1
    static let speedScalingPerWave: CGFloat = 1.02

    // Enemy type configurations - skill-based with dodgeable projectiles
    enum Chaser {
        static let baseHealth: CGFloat = 15
        static let baseSpeed: CGFloat = 180  // Slightly slower
        static let baseDamage: CGFloat = 8
        static let size: CGFloat = 30
        static let color: SKColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        static let xpValue: Int = 15
        // Goblins throw daggers!
        static let canShoot: Bool = true
        static let projectileSpeed: CGFloat = 120  // Slow - dodgeable!
        static let attackRange: CGFloat = 250
        static let attackCooldown: TimeInterval = 2.5
    }

    enum Swarm {
        static let baseHealth: CGFloat = 8  // Very fragile
        static let baseSpeed: CGFloat = 250  // Fast swarm - melee only
        static let baseDamage: CGFloat = 5
        static let size: CGFloat = 20
        static let color: SKColor = SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)
        static let xpValue: Int = 8
        static let canShoot: Bool = false  // Bats just swarm
    }

    enum Ranged {
        static let baseHealth: CGFloat = 12
        static let baseSpeed: CGFloat = 100  // Slower - keeps distance
        static let baseDamage: CGFloat = 15  // Hurts more
        static let size: CGFloat = 28
        static let color: SKColor = SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)
        static let attackRange: CGFloat = 400
        static let projectileSpeed: CGFloat = 150  // Slow arrows - dodge them!
        static let attackCooldown: TimeInterval = 1.2  // Faster shooting
        static let xpValue: Int = 20
    }

    enum Tank {
        static let baseHealth: CGFloat = 80
        static let baseSpeed: CGFloat = 80  // Slow
        static let baseDamage: CGFloat = 25
        static let size: CGFloat = 50
        static let color: SKColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        static let xpValue: Int = 40
        // Orcs throw boulders!
        static let canShoot: Bool = true
        static let projectileSpeed: CGFloat = 100  // Very slow - easy to dodge
        static let attackRange: CGFloat = 300
        static let attackCooldown: TimeInterval = 3.0  // Slow but deadly
    }

    // Suicide enemy - explodes when near player, forces movement
    enum Suicide {
        static let baseHealth: CGFloat = 20
        static let baseSpeed: CGFloat = 220  // Fast - rushes player
        static let baseDamage: CGFloat = 40  // High explosion damage
        static let size: CGFloat = 25
        static let color: SKColor = SKColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 1.0)  // Orange-red
        static let xpValue: Int = 25
        static let explosionRadius: CGFloat = 80
        static let fuseTime: TimeInterval = 1.5  // Time before exploding when in range
        static let triggerRange: CGFloat = 50  // Range to start fuse
    }

    // Buffer enemy - strengthens nearby allies
    enum Buffer {
        static let baseHealth: CGFloat = 25
        static let baseSpeed: CGFloat = 100
        static let baseDamage: CGFloat = 5
        static let size: CGFloat = 32
        static let color: SKColor = SKColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1.0)  // Purple
        static let xpValue: Int = 35
        static let buffRadius: CGFloat = 150
        static let buffInterval: TimeInterval = 3.0
        static let damageBuffPercent: CGFloat = 0.3  // 30% damage boost
        static let speedBuffPercent: CGFloat = 0.2   // 20% speed boost
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

    // First 3 waves spawn configuration - ACTION PACKED!
    static let wave1Enemies: [(EnemyType, Int)] = [(.chaser, 12), (.swarm, 8)]
    static let wave2Enemies: [(EnemyType, Int)] = [(.chaser, 15), (.swarm, 12), (.ranged, 3)]
    static let wave3Enemies: [(EnemyType, Int)] = [(.chaser, 12), (.swarm, 15), (.ranged, 5), (.tank, 2)]

    // WAVE 10+ SKILL CHECKS
    static let hardModeWave: Int = 10

    // After wave 10: Projectiles get faster
    static let projectileSpeedScalingPerWave: CGFloat = 1.08  // 8% faster per wave after 10

    // After wave 10: Enemies shoot more projectiles
    static let multiShotWave: Int = 10
    static let multiShotCount: Int = 3  // Enemies fire 3-shot spread

    // After wave 12: Charging enemies
    static let chargeWave: Int = 12
    static let chargeSpeed: CGFloat = 500  // Fast charge attack
    static let chargeCooldown: TimeInterval = 4.0

    // After wave 15: Danger zones spawn
    static let dangerZoneWave: Int = 15
    static let dangerZoneInterval: TimeInterval = 8.0
    static let dangerZoneDamage: CGFloat = 20
    static let dangerZoneRadius: CGFloat = 80
    static let dangerZoneDuration: TimeInterval = 3.0
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
        // Advanced abilities (wave 5+)
        static let timeSlow: TimeInterval = 12.0
        static let teleport: TimeInterval = 5.0
        static let reflect: TimeInterval = 10.0
        static let vortex: TimeInterval = 15.0
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
    case suicide   // Explodes near player - forces movement
    case buffer    // Strengthens nearby allies
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

    // Active abilities (early game)
    case dash
    case aoeBlast
    case shield
    case multishot
    case piercing
    case homing

    // Advanced abilities (unlocked after wave 5)
    case timeSlow       // Slow all enemies for 3 seconds
    case teleport       // Instant teleport with i-frames
    case reflect        // Reflect enemy projectiles back
    case vortex         // Pull enemies in then explode

    var isActive: Bool {
        switch self {
        case .dash, .aoeBlast, .shield, .timeSlow, .teleport, .reflect, .vortex:
            return true
        default:
            return false
        }
    }

    var isAdvanced: Bool {
        switch self {
        case .timeSlow, .teleport, .reflect, .vortex:
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
        case .timeSlow: return "Time Slow"
        case .teleport: return "Teleport"
        case .reflect: return "Reflect"
        case .vortex: return "Vortex"
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
        case .timeSlow: return "Slow time for 3s"
        case .teleport: return "Blink to safety"
        case .reflect: return "Reflect projectiles"
        case .vortex: return "Pull & explode"
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
        case .timeSlow: return SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)  // Purple
        case .teleport: return SKColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 1.0)  // Cyan
        case .reflect: return SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)   // Gold
        case .vortex: return SKColor(red: 0.9, green: 0.2, blue: 0.5, alpha: 1.0)    // Magenta
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
