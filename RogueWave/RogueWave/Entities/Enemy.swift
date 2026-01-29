//
//  Enemy.swift
//  RogueWave
//
//  Base enemy class and enemy type implementations
//  Includes: Chaser, Swarm, Ranged, Tank, Elite, Boss
//

import SpriteKit

// MARK: - Enemy Delegate Protocol

protocol EnemyDelegate: AnyObject {
    func enemyDidDie(_ enemy: Enemy)
    func enemyDidShoot(_ enemy: Enemy, projectile: Projectile)
    func enemyDidDamagePlayer(_ enemy: Enemy, damage: CGFloat)
}

// MARK: - Base Enemy Class

class Enemy: SKNode {

    // MARK: - Properties

    weak var delegate: EnemyDelegate?

    // Visual
    var spriteNode: SKShapeNode!
    private var healthBar: SKShapeNode?
    private var healthBarBackground: SKShapeNode?

    // Stats
    var enemyType: EnemyType
    var maxHealth: CGFloat
    var currentHealth: CGFloat
    var moveSpeed: CGFloat
    var damage: CGFloat
    var xpValue: Int
    var isElite: Bool = false
    var isBoss: Bool = false

    // State
    var isDead: Bool = false
    var isActive: Bool = false
    private var lastAttackTime: TimeInterval = 0
    var attackCooldown: TimeInterval = 1.0

    // For ranged enemies
    var attackRange: CGFloat = 0
    var projectileSpeed: CGFloat = 0
    var canShoot: Bool = false

    // For regenerating modifier
    var regenRate: CGFloat = 0

    // Wave 10+ skill checks
    var waveNumber: Int = 1
    var canMultiShot: Bool = false  // Fires spread pattern
    var canCharge: Bool = false      // Charges at player
    var isCharging: Bool = false
    var chargeCooldown: TimeInterval = 0
    var lastChargeTime: TimeInterval = 0

    // Suicide enemy properties
    var isSuicideType: Bool = false
    var fuseActive: Bool = false
    var fuseTimer: TimeInterval = 0
    var explosionRadius: CGFloat = 0
    var hasExploded: Bool = false

    // Buffer enemy properties
    var isBufferType: Bool = false
    var lastBuffTime: TimeInterval = 0
    var buffRadius: CGFloat = 0
    var isBuffed: Bool = false  // Whether this enemy has been buffed by a buffer
    var buffedDamageMultiplier: CGFloat = 1.0
    var buffedSpeedMultiplier: CGFloat = 1.0

    // Target reference
    weak var target: Player?

    // MARK: - Initialization

    init(type: EnemyType, waveNumber: Int = 1, isElite: Bool = false, isBoss: Bool = false) {
        self.enemyType = type
        self.isElite = isElite
        self.isBoss = isBoss
        self.waveNumber = waveNumber

        // Wave 10+ skill checks - enable advanced behaviors
        if waveNumber >= WaveConfig.multiShotWave && type != .swarm {
            self.canMultiShot = true
        }
        if waveNumber >= WaveConfig.chargeWave && (type == .chaser || type == .tank) {
            self.canCharge = true
            self.chargeCooldown = WaveConfig.chargeCooldown
        }

        // Calculate base stats based on type
        var baseHealth: CGFloat = 0
        var baseSpeed: CGFloat = 0
        var baseDamage: CGFloat = 0
        var baseXP: Int = 0
        var size: CGFloat = 0
        var color: SKColor = .red

        switch type {
        case .chaser:
            baseHealth = EnemyConfig.Chaser.baseHealth
            baseSpeed = EnemyConfig.Chaser.baseSpeed
            baseDamage = EnemyConfig.Chaser.baseDamage
            baseXP = EnemyConfig.Chaser.xpValue
            size = EnemyConfig.Chaser.size
            color = EnemyConfig.Chaser.color
            // Goblins throw daggers!
            self.canShoot = EnemyConfig.Chaser.canShoot
            self.projectileSpeed = EnemyConfig.Chaser.projectileSpeed
            self.attackRange = EnemyConfig.Chaser.attackRange
            self.attackCooldown = EnemyConfig.Chaser.attackCooldown

        case .swarm:
            baseHealth = EnemyConfig.Swarm.baseHealth
            baseSpeed = EnemyConfig.Swarm.baseSpeed
            baseDamage = EnemyConfig.Swarm.baseDamage
            baseXP = EnemyConfig.Swarm.xpValue
            size = EnemyConfig.Swarm.size
            color = EnemyConfig.Swarm.color
            self.canShoot = EnemyConfig.Swarm.canShoot

        case .ranged:
            baseHealth = EnemyConfig.Ranged.baseHealth
            baseSpeed = EnemyConfig.Ranged.baseSpeed
            baseDamage = EnemyConfig.Ranged.baseDamage
            baseXP = EnemyConfig.Ranged.xpValue
            size = EnemyConfig.Ranged.size
            color = EnemyConfig.Ranged.color
            self.attackRange = EnemyConfig.Ranged.attackRange
            self.projectileSpeed = EnemyConfig.Ranged.projectileSpeed
            self.attackCooldown = EnemyConfig.Ranged.attackCooldown
            self.canShoot = true

        case .tank:
            baseHealth = EnemyConfig.Tank.baseHealth
            baseSpeed = EnemyConfig.Tank.baseSpeed
            baseDamage = EnemyConfig.Tank.baseDamage
            baseXP = EnemyConfig.Tank.xpValue
            size = EnemyConfig.Tank.size
            color = EnemyConfig.Tank.color
            // Orcs throw boulders!
            self.canShoot = EnemyConfig.Tank.canShoot
            self.projectileSpeed = EnemyConfig.Tank.projectileSpeed
            self.attackRange = EnemyConfig.Tank.attackRange
            self.attackCooldown = EnemyConfig.Tank.attackCooldown

        case .suicide:
            baseHealth = EnemyConfig.Suicide.baseHealth
            baseSpeed = EnemyConfig.Suicide.baseSpeed
            baseDamage = EnemyConfig.Suicide.baseDamage
            baseXP = EnemyConfig.Suicide.xpValue
            size = EnemyConfig.Suicide.size
            color = EnemyConfig.Suicide.color
            self.isSuicideType = true
            self.explosionRadius = EnemyConfig.Suicide.explosionRadius
            self.canShoot = false

        case .buffer:
            baseHealth = EnemyConfig.Buffer.baseHealth
            baseSpeed = EnemyConfig.Buffer.baseSpeed
            baseDamage = EnemyConfig.Buffer.baseDamage
            baseXP = EnemyConfig.Buffer.xpValue
            size = EnemyConfig.Buffer.size
            color = EnemyConfig.Buffer.color
            self.isBufferType = true
            self.buffRadius = EnemyConfig.Buffer.buffRadius
            self.canShoot = false

        case .elite, .boss:
            // Elite and boss are modifiers applied to other types
            baseHealth = EnemyConfig.Chaser.baseHealth
            baseSpeed = EnemyConfig.Chaser.baseSpeed
            baseDamage = EnemyConfig.Chaser.baseDamage
            baseXP = EnemyConfig.Chaser.xpValue
            size = EnemyConfig.Chaser.size
            color = EnemyConfig.Chaser.color
        }

        // Apply wave scaling
        let waveMultiplier = CGFloat(waveNumber - 1)
        self.maxHealth = baseHealth * pow(EnemyConfig.healthScalingPerWave, waveMultiplier)
        self.moveSpeed = baseSpeed * pow(EnemyConfig.speedScalingPerWave, waveMultiplier)
        self.damage = baseDamage * pow(EnemyConfig.damageScalingPerWave, waveMultiplier)
        self.xpValue = baseXP

        // Apply elite modifier
        if isElite {
            self.maxHealth *= EnemyConfig.Elite.healthMultiplier
            self.damage *= EnemyConfig.Elite.damageMultiplier
            size *= EnemyConfig.Elite.sizeMultiplier
            self.xpValue *= EnemyConfig.Elite.xpMultiplier
        }

        // Apply boss modifier
        if isBoss {
            self.maxHealth *= EnemyConfig.Boss.healthMultiplier
            self.damage *= EnemyConfig.Boss.damageMultiplier
            size *= EnemyConfig.Boss.sizeMultiplier
            self.xpValue *= EnemyConfig.Boss.xpMultiplier
            color = EnemyConfig.Boss.color
        }

        self.currentHealth = self.maxHealth

        // Wave 10+ projectile speed scaling - projectiles get faster!
        if waveNumber > WaveConfig.hardModeWave && self.canShoot {
            let wavesAfterHard = CGFloat(waveNumber - WaveConfig.hardModeWave)
            let speedMultiplier = pow(WaveConfig.projectileSpeedScalingPerWave, wavesAfterHard)
            self.projectileSpeed *= speedMultiplier
        }

        super.init()

        setupVisuals(size: size, color: color)
        setupPhysics(size: size)
        setupHealthBar(size: size)

        if isElite {
            addEliteGlow()
        }

        if isBoss {
            addBossEffects()
        }

        zPosition = GameConfig.ZPosition.enemy
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupVisuals(size: CGFloat, color: SKColor) {
        // Create detailed monster based on enemy type
        switch enemyType {
        case .chaser, .elite, .boss:
            setupGoblin(size: size)
        case .swarm:
            setupBat(size: size)
        case .ranged:
            setupSkeletonArcher(size: size)
        case .tank:
            setupOrc(size: size)
        case .suicide:
            setupSuicideBomber(size: size)
        case .buffer:
            setupBufferMage(size: size)
        }
    }

    private func setupGoblin(size: CGFloat) {
        // Goblin body - hunched creature
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -size * 0.3, y: -size * 0.4))
        bodyPath.addLine(to: CGPoint(x: -size * 0.35, y: 0))
        bodyPath.addLine(to: CGPoint(x: -size * 0.2, y: size * 0.2))
        bodyPath.addLine(to: CGPoint(x: size * 0.2, y: size * 0.2))
        bodyPath.addLine(to: CGPoint(x: size * 0.35, y: 0))
        bodyPath.addLine(to: CGPoint(x: size * 0.3, y: -size * 0.4))
        bodyPath.closeSubpath()

        spriteNode = SKShapeNode(path: bodyPath)
        spriteNode.fillColor = SKColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1.0) // Green goblin
        spriteNode.strokeColor = SKColor(red: 0.2, green: 0.35, blue: 0.15, alpha: 1.0)
        spriteNode.lineWidth = 2
        addChild(spriteNode)

        // Head
        let head = SKShapeNode(circleOfRadius: size * 0.25)
        head.fillColor = SKColor(red: 0.35, green: 0.55, blue: 0.25, alpha: 1.0)
        head.strokeColor = SKColor(red: 0.2, green: 0.35, blue: 0.15, alpha: 1.0)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: size * 0.15)
        spriteNode.addChild(head)

        // Pointy ears
        let leftEar = SKShapeNode(ellipseOf: CGSize(width: size * 0.15, height: size * 0.3))
        leftEar.fillColor = SKColor(red: 0.35, green: 0.55, blue: 0.25, alpha: 1.0)
        leftEar.strokeColor = .clear
        leftEar.position = CGPoint(x: -size * 0.25, y: size * 0.1)
        leftEar.zRotation = 0.5
        head.addChild(leftEar)

        let rightEar = SKShapeNode(ellipseOf: CGSize(width: size * 0.15, height: size * 0.3))
        rightEar.fillColor = SKColor(red: 0.35, green: 0.55, blue: 0.25, alpha: 1.0)
        rightEar.strokeColor = .clear
        rightEar.position = CGPoint(x: size * 0.25, y: size * 0.1)
        rightEar.zRotation = -0.5
        head.addChild(rightEar)

        // Evil eyes
        let leftEye = SKShapeNode(circleOfRadius: size * 0.06)
        leftEye.fillColor = SKColor.red
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -size * 0.1, y: 0)
        leftEye.glowWidth = 2
        head.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: size * 0.06)
        rightEye.fillColor = SKColor.red
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: size * 0.1, y: 0)
        rightEye.glowWidth = 2
        head.addChild(rightEye)

        // Mouth with fangs
        let mouth = SKShapeNode(rectOf: CGSize(width: size * 0.15, height: size * 0.05))
        mouth.fillColor = SKColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1.0)
        mouth.strokeColor = .clear
        mouth.position = CGPoint(x: 0, y: -size * 0.12)
        head.addChild(mouth)
    }

    private func setupBat(size: CGFloat) {
        // Bat body
        let body = SKShapeNode(ellipseOf: CGSize(width: size * 0.5, height: size * 0.6))
        body.fillColor = SKColor(red: 0.15, green: 0.1, blue: 0.2, alpha: 1.0)
        body.strokeColor = SKColor(red: 0.25, green: 0.15, blue: 0.3, alpha: 1.0)
        body.lineWidth = 1

        spriteNode = body
        addChild(spriteNode)

        // Left wing
        let leftWingPath = CGMutablePath()
        leftWingPath.move(to: CGPoint(x: -size * 0.15, y: 0))
        leftWingPath.addQuadCurve(to: CGPoint(x: -size * 0.5, y: size * 0.1),
                                   control: CGPoint(x: -size * 0.35, y: size * 0.25))
        leftWingPath.addQuadCurve(to: CGPoint(x: -size * 0.4, y: -size * 0.15),
                                   control: CGPoint(x: -size * 0.55, y: -size * 0.1))
        leftWingPath.addQuadCurve(to: CGPoint(x: -size * 0.15, y: -size * 0.1),
                                   control: CGPoint(x: -size * 0.25, y: -size * 0.2))
        leftWingPath.closeSubpath()

        let leftWing = SKShapeNode(path: leftWingPath)
        leftWing.fillColor = SKColor(red: 0.2, green: 0.12, blue: 0.25, alpha: 0.9)
        leftWing.strokeColor = SKColor(red: 0.3, green: 0.2, blue: 0.35, alpha: 1.0)
        leftWing.lineWidth = 1
        spriteNode.addChild(leftWing)

        // Right wing (mirrored)
        let rightWingPath = CGMutablePath()
        rightWingPath.move(to: CGPoint(x: size * 0.15, y: 0))
        rightWingPath.addQuadCurve(to: CGPoint(x: size * 0.5, y: size * 0.1),
                                    control: CGPoint(x: size * 0.35, y: size * 0.25))
        rightWingPath.addQuadCurve(to: CGPoint(x: size * 0.4, y: -size * 0.15),
                                    control: CGPoint(x: size * 0.55, y: -size * 0.1))
        rightWingPath.addQuadCurve(to: CGPoint(x: size * 0.15, y: -size * 0.1),
                                    control: CGPoint(x: size * 0.25, y: -size * 0.2))
        rightWingPath.closeSubpath()

        let rightWing = SKShapeNode(path: rightWingPath)
        rightWing.fillColor = SKColor(red: 0.2, green: 0.12, blue: 0.25, alpha: 0.9)
        rightWing.strokeColor = SKColor(red: 0.3, green: 0.2, blue: 0.35, alpha: 1.0)
        rightWing.lineWidth = 1
        spriteNode.addChild(rightWing)

        // Eyes
        let leftEye = SKShapeNode(circleOfRadius: size * 0.08)
        leftEye.fillColor = SKColor.yellow
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -size * 0.1, y: size * 0.1)
        leftEye.glowWidth = 2
        spriteNode.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: size * 0.08)
        rightEye.fillColor = SKColor.yellow
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: size * 0.1, y: size * 0.1)
        rightEye.glowWidth = 2
        spriteNode.addChild(rightEye)

        // Fangs
        let leftFang = SKShapeNode(rectOf: CGSize(width: size * 0.04, height: size * 0.12))
        leftFang.fillColor = SKColor.white
        leftFang.strokeColor = .clear
        leftFang.position = CGPoint(x: -size * 0.06, y: -size * 0.15)
        spriteNode.addChild(leftFang)

        let rightFang = SKShapeNode(rectOf: CGSize(width: size * 0.04, height: size * 0.12))
        rightFang.fillColor = SKColor.white
        rightFang.strokeColor = .clear
        rightFang.position = CGPoint(x: size * 0.06, y: -size * 0.15)
        spriteNode.addChild(rightFang)

        // Wing flap animation
        let flapUp = SKAction.scaleY(to: 1.1, duration: 0.15)
        let flapDown = SKAction.scaleY(to: 0.9, duration: 0.15)
        let flapSequence = SKAction.sequence([flapUp, flapDown])
        leftWing.run(SKAction.repeatForever(flapSequence))
        rightWing.run(SKAction.repeatForever(flapSequence))
    }

    private func setupSkeletonArcher(size: CGFloat) {
        // Skeleton body (ribcage shape)
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -size * 0.25, y: -size * 0.35))
        bodyPath.addLine(to: CGPoint(x: -size * 0.2, y: size * 0.1))
        bodyPath.addLine(to: CGPoint(x: 0, y: size * 0.15))
        bodyPath.addLine(to: CGPoint(x: size * 0.2, y: size * 0.1))
        bodyPath.addLine(to: CGPoint(x: size * 0.25, y: -size * 0.35))
        bodyPath.closeSubpath()

        spriteNode = SKShapeNode(path: bodyPath)
        spriteNode.fillColor = SKColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1.0) // Bone color
        spriteNode.strokeColor = SKColor(red: 0.6, green: 0.55, blue: 0.5, alpha: 1.0)
        spriteNode.lineWidth = 2
        addChild(spriteNode)

        // Skull
        let skull = SKShapeNode(circleOfRadius: size * 0.22)
        skull.fillColor = SKColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1.0)
        skull.strokeColor = SKColor(red: 0.6, green: 0.55, blue: 0.5, alpha: 1.0)
        skull.lineWidth = 1
        skull.position = CGPoint(x: 0, y: size * 0.25)
        spriteNode.addChild(skull)

        // Eye sockets (dark)
        let leftSocket = SKShapeNode(circleOfRadius: size * 0.07)
        leftSocket.fillColor = SKColor(red: 0.1, green: 0.05, blue: 0.15, alpha: 1.0)
        leftSocket.strokeColor = .clear
        leftSocket.position = CGPoint(x: -size * 0.1, y: size * 0.03)
        skull.addChild(leftSocket)

        let rightSocket = SKShapeNode(circleOfRadius: size * 0.07)
        rightSocket.fillColor = SKColor(red: 0.1, green: 0.05, blue: 0.15, alpha: 1.0)
        rightSocket.strokeColor = .clear
        rightSocket.position = CGPoint(x: size * 0.1, y: size * 0.03)
        skull.addChild(rightSocket)

        // Glowing eyes inside sockets
        let leftGlow = SKShapeNode(circleOfRadius: size * 0.03)
        leftGlow.fillColor = SKColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        leftGlow.strokeColor = .clear
        leftGlow.glowWidth = 3
        leftSocket.addChild(leftGlow)

        let rightGlow = SKShapeNode(circleOfRadius: size * 0.03)
        rightGlow.fillColor = SKColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        rightGlow.strokeColor = .clear
        rightGlow.glowWidth = 3
        rightSocket.addChild(rightGlow)

        // Nose hole
        let nose = SKShapeNode(ellipseOf: CGSize(width: size * 0.06, height: size * 0.08))
        nose.fillColor = SKColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 0, y: -size * 0.05)
        skull.addChild(nose)

        // Bow
        let bowPath = CGMutablePath()
        bowPath.move(to: CGPoint(x: size * 0.35, y: size * 0.25))
        bowPath.addQuadCurve(to: CGPoint(x: size * 0.35, y: -size * 0.25),
                              control: CGPoint(x: size * 0.55, y: 0))
        let bow = SKShapeNode(path: bowPath)
        bow.fillColor = .clear
        bow.strokeColor = SKColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1.0)
        bow.lineWidth = 3
        spriteNode.addChild(bow)

        // Bowstring
        let stringPath = CGMutablePath()
        stringPath.move(to: CGPoint(x: size * 0.35, y: size * 0.25))
        stringPath.addLine(to: CGPoint(x: size * 0.35, y: -size * 0.25))
        let bowString = SKShapeNode(path: stringPath)
        bowString.strokeColor = SKColor(red: 0.7, green: 0.65, blue: 0.6, alpha: 1.0)
        bowString.lineWidth = 1
        spriteNode.addChild(bowString)
    }

    private func setupOrc(size: CGFloat) {
        // Large orc body
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -size * 0.4, y: -size * 0.4))
        bodyPath.addLine(to: CGPoint(x: -size * 0.45, y: size * 0.1))
        bodyPath.addLine(to: CGPoint(x: -size * 0.3, y: size * 0.25))
        bodyPath.addLine(to: CGPoint(x: size * 0.3, y: size * 0.25))
        bodyPath.addLine(to: CGPoint(x: size * 0.45, y: size * 0.1))
        bodyPath.addLine(to: CGPoint(x: size * 0.4, y: -size * 0.4))
        bodyPath.closeSubpath()

        spriteNode = SKShapeNode(path: bodyPath)
        spriteNode.fillColor = SKColor(red: 0.35, green: 0.45, blue: 0.3, alpha: 1.0) // Olive green
        spriteNode.strokeColor = SKColor(red: 0.25, green: 0.3, blue: 0.2, alpha: 1.0)
        spriteNode.lineWidth = 3
        addChild(spriteNode)

        // Armor chest plate
        let armor = SKShapeNode(rectOf: CGSize(width: size * 0.5, height: size * 0.35), cornerRadius: 3)
        armor.fillColor = SKColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1.0)
        armor.strokeColor = SKColor(red: 0.5, green: 0.45, blue: 0.4, alpha: 1.0)
        armor.lineWidth = 2
        armor.position = CGPoint(x: 0, y: -size * 0.05)
        spriteNode.addChild(armor)

        // Head
        let head = SKShapeNode(circleOfRadius: size * 0.28)
        head.fillColor = SKColor(red: 0.4, green: 0.5, blue: 0.35, alpha: 1.0)
        head.strokeColor = SKColor(red: 0.25, green: 0.3, blue: 0.2, alpha: 1.0)
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: size * 0.2)
        spriteNode.addChild(head)

        // Angry eyes
        let leftEye = SKShapeNode(ellipseOf: CGSize(width: size * 0.12, height: size * 0.08))
        leftEye.fillColor = SKColor.yellow
        leftEye.strokeColor = SKColor.red
        leftEye.lineWidth = 1
        leftEye.position = CGPoint(x: -size * 0.12, y: size * 0.05)
        head.addChild(leftEye)

        let rightEye = SKShapeNode(ellipseOf: CGSize(width: size * 0.12, height: size * 0.08))
        rightEye.fillColor = SKColor.yellow
        rightEye.strokeColor = SKColor.red
        rightEye.lineWidth = 1
        rightEye.position = CGPoint(x: size * 0.12, y: size * 0.05)
        head.addChild(rightEye)

        // Pupils
        let leftPupil = SKShapeNode(circleOfRadius: size * 0.03)
        leftPupil.fillColor = SKColor.black
        leftPupil.strokeColor = .clear
        leftEye.addChild(leftPupil)

        let rightPupil = SKShapeNode(circleOfRadius: size * 0.03)
        rightPupil.fillColor = SKColor.black
        rightPupil.strokeColor = .clear
        rightEye.addChild(rightPupil)

        // Tusks
        let leftTusk = SKShapeNode(ellipseOf: CGSize(width: size * 0.08, height: size * 0.18))
        leftTusk.fillColor = SKColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1.0)
        leftTusk.strokeColor = SKColor(red: 0.8, green: 0.75, blue: 0.65, alpha: 1.0)
        leftTusk.lineWidth = 1
        leftTusk.position = CGPoint(x: -size * 0.15, y: -size * 0.18)
        leftTusk.zRotation = 0.3
        head.addChild(leftTusk)

        let rightTusk = SKShapeNode(ellipseOf: CGSize(width: size * 0.08, height: size * 0.18))
        rightTusk.fillColor = SKColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1.0)
        rightTusk.strokeColor = SKColor(red: 0.8, green: 0.75, blue: 0.65, alpha: 1.0)
        rightTusk.lineWidth = 1
        rightTusk.position = CGPoint(x: size * 0.15, y: -size * 0.18)
        rightTusk.zRotation = -0.3
        head.addChild(rightTusk)

        // War paint/scar
        let scar = SKShapeNode(rectOf: CGSize(width: size * 0.25, height: size * 0.03))
        scar.fillColor = SKColor(red: 0.6, green: 0.15, blue: 0.1, alpha: 0.8)
        scar.strokeColor = .clear
        scar.position = CGPoint(x: 0, y: size * 0.12)
        scar.zRotation = -0.2
        head.addChild(scar)
    }

    private func setupSuicideBomber(size: CGFloat) {
        // Round bomb-like body
        spriteNode = SKShapeNode(circleOfRadius: size * 0.45)
        spriteNode.fillColor = SKColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)  // Dark bomb color
        spriteNode.strokeColor = SKColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        spriteNode.lineWidth = 3
        addChild(spriteNode)

        // Fuse on top
        let fusePath = CGMutablePath()
        fusePath.move(to: CGPoint(x: 0, y: size * 0.35))
        fusePath.addQuadCurve(to: CGPoint(x: size * 0.15, y: size * 0.55),
                               control: CGPoint(x: size * 0.2, y: size * 0.4))
        let fuse = SKShapeNode(path: fusePath)
        fuse.strokeColor = SKColor(red: 0.6, green: 0.5, blue: 0.3, alpha: 1.0)
        fuse.lineWidth = 3
        fuse.name = "fuse"
        spriteNode.addChild(fuse)

        // Spark at fuse tip (initially hidden)
        let spark = SKShapeNode(circleOfRadius: size * 0.08)
        spark.fillColor = SKColor.orange
        spark.strokeColor = SKColor.yellow
        spark.glowWidth = 8
        spark.position = CGPoint(x: size * 0.15, y: size * 0.55)
        spark.name = "spark"
        spark.isHidden = true
        spriteNode.addChild(spark)

        // Angry face on bomb
        let leftEye = SKShapeNode(circleOfRadius: size * 0.08)
        leftEye.fillColor = SKColor.red
        leftEye.strokeColor = .clear
        leftEye.glowWidth = 3
        leftEye.position = CGPoint(x: -size * 0.15, y: size * 0.1)
        spriteNode.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: size * 0.08)
        rightEye.fillColor = SKColor.red
        rightEye.strokeColor = .clear
        rightEye.glowWidth = 3
        rightEye.position = CGPoint(x: size * 0.15, y: size * 0.1)
        spriteNode.addChild(rightEye)

        // Angry mouth
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -size * 0.15, y: -size * 0.1))
        mouthPath.addQuadCurve(to: CGPoint(x: size * 0.15, y: -size * 0.1),
                                control: CGPoint(x: 0, y: -size * 0.2))
        let mouth = SKShapeNode(path: mouthPath)
        mouth.strokeColor = SKColor.red
        mouth.lineWidth = 2
        spriteNode.addChild(mouth)

        // Warning symbol
        let warning = SKLabelNode(fontNamed: UIConfig.fontName)
        warning.text = "!"
        warning.fontSize = size * 0.4
        warning.fontColor = SKColor.yellow
        warning.position = CGPoint(x: 0, y: -size * 0.35)
        warning.isHidden = true
        warning.name = "warning"
        spriteNode.addChild(warning)
    }

    private func setupBufferMage(size: CGFloat) {
        // Robed mage body
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -size * 0.35, y: -size * 0.4))
        bodyPath.addLine(to: CGPoint(x: -size * 0.25, y: size * 0.1))
        bodyPath.addLine(to: CGPoint(x: 0, y: size * 0.2))
        bodyPath.addLine(to: CGPoint(x: size * 0.25, y: size * 0.1))
        bodyPath.addLine(to: CGPoint(x: size * 0.35, y: -size * 0.4))
        bodyPath.closeSubpath()

        spriteNode = SKShapeNode(path: bodyPath)
        spriteNode.fillColor = SKColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0)  // Purple robe
        spriteNode.strokeColor = SKColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0)
        spriteNode.lineWidth = 2
        addChild(spriteNode)

        // Hood/head
        let hood = SKShapeNode(circleOfRadius: size * 0.22)
        hood.fillColor = SKColor(red: 0.35, green: 0.15, blue: 0.5, alpha: 1.0)
        hood.strokeColor = SKColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1.0)
        hood.lineWidth = 2
        hood.position = CGPoint(x: 0, y: size * 0.15)
        spriteNode.addChild(hood)

        // Glowing eyes
        let leftEye = SKShapeNode(circleOfRadius: size * 0.05)
        leftEye.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        leftEye.strokeColor = .clear
        leftEye.glowWidth = 5
        leftEye.position = CGPoint(x: -size * 0.08, y: 0)
        hood.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: size * 0.05)
        rightEye.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        rightEye.strokeColor = .clear
        rightEye.glowWidth = 5
        rightEye.position = CGPoint(x: size * 0.08, y: 0)
        hood.addChild(rightEye)

        // Staff
        let staffPath = CGMutablePath()
        staffPath.move(to: CGPoint(x: size * 0.35, y: -size * 0.3))
        staffPath.addLine(to: CGPoint(x: size * 0.4, y: size * 0.45))
        let staff = SKShapeNode(path: staffPath)
        staff.strokeColor = SKColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1.0)
        staff.lineWidth = 4
        spriteNode.addChild(staff)

        // Staff orb
        let orb = SKShapeNode(circleOfRadius: size * 0.12)
        orb.fillColor = SKColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 0.8)
        orb.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 1.0, alpha: 1.0)
        orb.lineWidth = 2
        orb.glowWidth = 10
        orb.position = CGPoint(x: size * 0.4, y: size * 0.5)
        orb.name = "staffOrb"
        spriteNode.addChild(orb)

        // Pulsing orb animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        orb.run(pulse)

        // Buff aura (shown when buffing)
        let aura = SKShapeNode(circleOfRadius: size * 0.6)
        aura.fillColor = SKColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 0.15)
        aura.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 1.0, alpha: 0.4)
        aura.lineWidth = 2
        aura.name = "buffAura"
        aura.isHidden = true
        spriteNode.addChild(aura)
    }

    private func setupPhysics(size: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: size / 2)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.PhysicsCategory.enemy
        body.contactTestBitMask = GameConfig.PhysicsCategory.player | GameConfig.PhysicsCategory.playerProjectile
        // Don't collide with boundary - enemies spawn outside and need to enter
        // Don't collide with other enemies - prevents clumping/blocking
        body.collisionBitMask = GameConfig.PhysicsCategory.none
        body.linearDamping = 1.0  // Reduced damping for smoother movement
        body.mass = isBoss ? 10 : (isElite ? 3 : 1)
        physicsBody = body
    }

    private func setupHealthBar(size: CGFloat) {
        let barWidth = size * 1.2
        let barHeight: CGFloat = 4

        // Background
        healthBarBackground = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 2)
        healthBarBackground?.fillColor = SKColor.darkGray
        healthBarBackground?.strokeColor = .clear
        healthBarBackground?.position = CGPoint(x: 0, y: size / 2 + 8)
        addChild(healthBarBackground!)

        // Foreground
        healthBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 2)
        healthBar?.fillColor = SKColor.red
        healthBar?.strokeColor = .clear
        healthBar?.position = CGPoint(x: 0, y: size / 2 + 8)
        addChild(healthBar!)

        // Initially hidden
        healthBarBackground?.isHidden = true
        healthBar?.isHidden = true
    }

    private func addEliteGlow() {
        spriteNode.glowWidth = 8
        spriteNode.strokeColor = EnemyConfig.Elite.glowColor

        // Pulsing animation
        let pulseAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run { [weak self] in self?.spriteNode.glowWidth = 12 },
                SKAction.wait(forDuration: 0.5),
                SKAction.run { [weak self] in self?.spriteNode.glowWidth = 8 },
                SKAction.wait(forDuration: 0.5)
            ])
        )
        run(pulseAction, withKey: "elitePulse")
    }

    private func addBossEffects() {
        spriteNode.glowWidth = 15
        spriteNode.lineWidth = 4

        // Rotating particles around boss
        let particleCount = 4
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 8)
            particle.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.8)
            particle.strokeColor = .clear

            let angle = CGFloat(i) * (.pi * 2 / CGFloat(particleCount))
            let radius: CGFloat = 40
            particle.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)

            addChild(particle)

            // Orbit animation
            let orbitPath = UIBezierPath(arcCenter: .zero, radius: radius, startAngle: angle, endAngle: angle + .pi * 2, clockwise: true)
            let orbitAction = SKAction.follow(orbitPath.cgPath, asOffset: false, orientToPath: false, duration: 2.0)
            particle.run(SKAction.repeatForever(orbitAction))
        }
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval) {
        guard !isDead, isActive, let target = target else { return }

        // Regeneration
        if regenRate > 0 {
            currentHealth = min(currentHealth + regenRate * CGFloat(deltaTime), maxHealth)
        }

        // Update charge cooldown
        if canCharge && !isCharging {
            lastChargeTime += deltaTime
        }

        // Special enemy type behaviors
        if isSuicideType {
            updateSuicideBehavior(deltaTime: deltaTime, target: target)
            return
        }

        if isBufferType {
            updateBufferBehavior(deltaTime: deltaTime, target: target)
            return
        }

        // Movement and attack behavior - enemies that can shoot use ranged behavior
        if canShoot {
            updateRangedBehavior(deltaTime: deltaTime, target: target)
        } else {
            updateChaserBehavior(deltaTime: deltaTime, target: target)
        }

        lastAttackTime += deltaTime
    }

    // MARK: - Suicide Enemy Behavior

    private func updateSuicideBehavior(deltaTime: TimeInterval, target: Player) {
        let distanceToTarget = distanceTo(target)
        let direction = directionTo(target)

        // Apply speed buff if buffed
        let effectiveSpeed = moveSpeed * buffedSpeedMultiplier

        // Always chase the player
        physicsBody?.velocity = CGVector(dx: direction.x * effectiveSpeed, dy: direction.y * effectiveSpeed)

        // Rotate to face player
        let angle = atan2(direction.y, direction.x) - .pi / 2
        spriteNode.zRotation = angle

        // Check if close enough to start fuse
        if distanceToTarget < EnemyConfig.Suicide.triggerRange && !fuseActive {
            startFuse()
        }

        // Update fuse timer
        if fuseActive {
            fuseTimer += deltaTime

            // Flash faster as timer progresses
            let flashRate = max(0.1, 0.3 - (fuseTimer / EnemyConfig.Suicide.fuseTime) * 0.2)
            if Int(fuseTimer / flashRate) % 2 == 0 {
                spriteNode.fillColor = SKColor.red
            } else {
                spriteNode.fillColor = SKColor.orange
            }

            // Explode when timer completes
            if fuseTimer >= EnemyConfig.Suicide.fuseTime {
                explode()
            }
        }
    }

    private func startFuse() {
        fuseActive = true
        fuseTimer = 0

        // Show spark
        if let spark = spriteNode.childNode(withName: "spark") {
            spark.isHidden = false
            // Flickering animation
            let flicker = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.05),
                SKAction.fadeAlpha(to: 1.0, duration: 0.05)
            ]))
            spark.run(flicker)
        }

        // Show warning
        if let warning = spriteNode.childNode(withName: "warning") {
            warning.isHidden = false
            let blink = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.15),
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ]))
            warning.run(blink)
        }

        // Ticking sound/haptic
        AudioManager.shared.triggerWarningHaptic()
    }

    private func explode() {
        guard !hasExploded else { return }
        hasExploded = true

        // Apply buff multiplier to damage
        let explosionDamage = damage * buffedDamageMultiplier

        // Check if player is in range
        if let target = target {
            let distanceToTarget = distanceTo(target)
            if distanceToTarget <= explosionRadius {
                delegate?.enemyDidDamagePlayer(self, damage: explosionDamage)
            }
        }

        // Visual explosion effect
        let explosion = SKShapeNode(circleOfRadius: explosionRadius)
        explosion.fillColor = SKColor.orange.withAlphaComponent(0.6)
        explosion.strokeColor = SKColor.red
        explosion.lineWidth = 4
        explosion.glowWidth = 15
        explosion.position = position
        explosion.zPosition = GameConfig.ZPosition.effects
        explosion.setScale(0.1)
        parent?.addChild(explosion)

        let expandAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.15),
                SKAction.fadeAlpha(to: 0.8, duration: 0.15)
            ]),
            SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ])
        explosion.run(expandAction)

        // Haptic feedback
        AudioManager.shared.triggerErrorHaptic()

        // Die after explosion
        die()
    }

    // MARK: - Buffer Enemy Behavior

    private func updateBufferBehavior(deltaTime: TimeInterval, target: Player) {
        let distanceToTarget = distanceTo(target)
        let direction = directionTo(target)

        // Buffers keep moderate distance from player
        let preferredDistance: CGFloat = 200

        if distanceToTarget > preferredDistance + 50 {
            // Move closer
            physicsBody?.velocity = CGVector(dx: direction.x * moveSpeed, dy: direction.y * moveSpeed)
        } else if distanceToTarget < preferredDistance - 50 {
            // Back away
            physicsBody?.velocity = CGVector(dx: -direction.x * moveSpeed * 0.5, dy: -direction.y * moveSpeed * 0.5)
        } else {
            // Stay in place
            physicsBody?.velocity = .zero
        }

        // Rotate to face player
        let angle = atan2(direction.y, direction.x) - .pi / 2
        spriteNode.zRotation = angle

        // Buff nearby allies periodically
        lastBuffTime += deltaTime
        if lastBuffTime >= EnemyConfig.Buffer.buffInterval {
            lastBuffTime = 0
            castBuff()
        }
    }

    private func castBuff() {
        // Show buff aura
        if let aura = spriteNode.childNode(withName: "buffAura") {
            aura.isHidden = false
            aura.setScale(0.5)
            aura.alpha = 0.8

            let expandFade = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 2.0, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.run { aura.isHidden = true; aura.setScale(0.5); aura.alpha = 0.8 }
            ])
            aura.run(expandFade)
        }

        // Staff orb glow
        if let orb = spriteNode.childNode(withName: "staffOrb") as? SKShapeNode {
            let originalGlow = orb.glowWidth
            orb.glowWidth = 20

            let resetGlow = SKAction.sequence([
                SKAction.wait(forDuration: 0.3),
                SKAction.run { orb.glowWidth = originalGlow }
            ])
            orb.run(resetGlow)
        }

        // Notify delegate to buff nearby enemies
        // This is handled by GameScene which has access to all enemies
        delegate?.enemyDidShoot(self, projectile: createBuffProjectile())
    }

    private func createBuffProjectile() -> Projectile {
        // Create a "fake" projectile that signals a buff event
        // GameScene will intercept this and apply buffs to nearby enemies
        let proj = Projectile(
            damage: 0,
            speed: 0,
            angle: 0,
            isPlayerProjectile: false,
            piercing: false,
            homing: false,
            isCritical: false
        )
        proj.name = "buff_signal"
        return proj
    }

    // Method to receive a buff from a buffer enemy
    func applyBuff(damageMultiplier: CGFloat, speedMultiplier: CGFloat) {
        guard !isBuffed else { return }  // Already buffed

        isBuffed = true
        buffedDamageMultiplier = damageMultiplier
        buffedSpeedMultiplier = speedMultiplier

        // Visual buff indicator
        let buffGlow = SKShapeNode(circleOfRadius: spriteNode.frame.width * 0.6)
        buffGlow.fillColor = SKColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 0.2)
        buffGlow.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 1.0, alpha: 0.6)
        buffGlow.lineWidth = 2
        buffGlow.name = "buffGlow"
        addChild(buffGlow)

        // Pulsing effect
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ]))
        buffGlow.run(pulse)

        // Buff expires after some time
        let expireBuff = SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.run { [weak self] in
                self?.removeBuff()
            }
        ])
        run(expireBuff, withKey: "buffExpire")
    }

    private func removeBuff() {
        isBuffed = false
        buffedDamageMultiplier = 1.0
        buffedSpeedMultiplier = 1.0

        if let buffGlow = childNode(withName: "buffGlow") {
            buffGlow.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func updateChaserBehavior(deltaTime: TimeInterval, target: Player) {
        let direction = directionTo(target)
        let distanceToTarget = distanceTo(target)

        // Check for charge attack (wave 12+)
        if canCharge && !isCharging && lastChargeTime >= chargeCooldown && distanceToTarget < 200 {
            startCharge(toward: target)
            return
        }

        // If currently charging, maintain charge velocity
        if isCharging {
            return  // Velocity is already set by charge
        }

        // Normal movement toward player
        physicsBody?.velocity = CGVector(dx: direction.x * moveSpeed, dy: direction.y * moveSpeed)

        // Rotate to face player
        let angle = atan2(direction.y, direction.x) - .pi / 2
        spriteNode.zRotation = angle
    }

    private func startCharge(toward target: Player) {
        isCharging = true
        lastChargeTime = 0

        // Telegraph the charge with a brief pause and visual
        let direction = directionTo(target)
        physicsBody?.velocity = .zero

        // Warning flash
        let originalColor = spriteNode.fillColor
        let warningAction = SKAction.sequence([
            SKAction.run { [weak self] in self?.spriteNode.fillColor = SKColor.red },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in self?.spriteNode.fillColor = SKColor.orange },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in self?.spriteNode.fillColor = originalColor }
        ])

        // Execute charge after telegraph
        let chargeAction = SKAction.sequence([
            warningAction,
            SKAction.run { [weak self] in
                guard let self = self else { return }
                // Launch at high speed in the direction
                self.physicsBody?.velocity = CGVector(
                    dx: direction.x * WaveConfig.chargeSpeed,
                    dy: direction.y * WaveConfig.chargeSpeed
                )
            },
            SKAction.wait(forDuration: 0.5),  // Charge duration
            SKAction.run { [weak self] in
                self?.isCharging = false
            }
        ])

        run(chargeAction, withKey: "chargeAttack")
    }

    private func updateRangedBehavior(deltaTime: TimeInterval, target: Player) {
        let distanceToTarget = distanceTo(target)
        let direction = directionTo(target)

        // Pure ranged (skeleton archers) - keep distance and shoot
        // Hybrid shooters (goblins, orcs) - chase and shoot
        let isPureRanged = enemyType == .ranged

        if isPureRanged {
            // Skeleton archers try to maintain distance
            if distanceToTarget > attackRange {
                // Move closer
                physicsBody?.velocity = CGVector(dx: direction.x * moveSpeed, dy: direction.y * moveSpeed)
            } else if distanceToTarget < attackRange * 0.5 {
                // Too close - back away slowly
                physicsBody?.velocity = CGVector(dx: -direction.x * moveSpeed * 0.5, dy: -direction.y * moveSpeed * 0.5)
            } else {
                // In good range - stop and shoot
                physicsBody?.velocity = .zero
            }
        } else {
            // Goblins and Orcs - chase while shooting
            physicsBody?.velocity = CGVector(dx: direction.x * moveSpeed, dy: direction.y * moveSpeed)
        }

        // Shoot if in range and cooldown is ready
        if distanceToTarget <= attackRange && lastAttackTime >= attackCooldown {
            shoot(at: target)
            lastAttackTime = 0
        }

        // Rotate to face player
        let angle = atan2(direction.y, direction.x) - .pi / 2
        spriteNode.zRotation = angle
    }

    private func shoot(at target: Player) {
        let baseAngle = angleTo(target)

        // Multi-shot spread pattern after wave 10
        if canMultiShot {
            let shotCount = WaveConfig.multiShotCount
            let spreadAngle: CGFloat = .pi / 6  // 30 degree total spread

            for i in 0..<shotCount {
                let angleOffset = spreadAngle * (CGFloat(i) - CGFloat(shotCount - 1) / 2) / CGFloat(max(shotCount - 1, 1))
                let shotAngle = baseAngle + angleOffset

                let projectile = Projectile(
                    damage: damage * 0.7,  // Slightly less damage per shot
                    speed: projectileSpeed,
                    angle: shotAngle,
                    isPlayerProjectile: false,
                    piercing: false,
                    homing: false,
                    isCritical: false
                )
                projectile.position = position
                delegate?.enemyDidShoot(self, projectile: projectile)
            }
        } else {
            // Single shot
            let projectile = Projectile(
                damage: damage,
                speed: projectileSpeed,
                angle: baseAngle,
                isPlayerProjectile: false,
                piercing: false,
                homing: false,
                isCritical: false
            )
            projectile.position = position
            delegate?.enemyDidShoot(self, projectile: projectile)
        }

        // Visual feedback
        let recoilAction = SKAction.sequence([
            SKAction.scale(to: 0.9, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.05)
        ])
        spriteNode.run(recoilAction)
    }

    // MARK: - Helper Functions

    private func directionTo(_ node: SKNode) -> CGPoint {
        let dx = node.position.x - position.x
        let dy = node.position.y - position.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0 else { return .zero }

        return CGPoint(x: dx / length, y: dy / length)
    }

    private func distanceTo(_ node: SKNode) -> CGFloat {
        let dx = node.position.x - position.x
        let dy = node.position.y - position.y
        return sqrt(dx * dx + dy * dy)
    }

    private func angleTo(_ node: SKNode) -> CGFloat {
        let dx = node.position.x - position.x
        let dy = node.position.y - position.y
        return atan2(dy, dx)
    }

    // MARK: - Damage and Death

    func takeDamage(_ amount: CGFloat, isCritical: Bool = false) {
        guard !isDead else { return }

        currentHealth -= amount

        // Show health bar
        healthBarBackground?.isHidden = false
        healthBar?.isHidden = false

        // Update health bar
        updateHealthBar()

        // Hit feedback
        showHitFeedback(isCritical: isCritical)

        // Damage number
        showDamageNumber(amount, isCritical: isCritical)

        if currentHealth <= 0 {
            die()
        }
    }

    private func updateHealthBar() {
        guard let healthBar = healthBar else { return }

        let healthPercent = max(0, currentHealth / maxHealth)
        healthBar.xScale = healthPercent
    }

    private func showHitFeedback(isCritical: Bool) {
        let flashColor = isCritical ? SKColor.yellow : SKColor.white
        let originalColor = spriteNode.fillColor

        let flashAction = SKAction.sequence([
            SKAction.run { [weak self] in self?.spriteNode.fillColor = flashColor },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.spriteNode.fillColor = originalColor }
        ])
        run(flashAction)

        // Knockback effect
        if let target = target {
            let direction = directionTo(target)
            let knockback = SKAction.moveBy(x: direction.x * -10, y: direction.y * -10, duration: 0.05)
            run(knockback)
        }
    }

    private func showDamageNumber(_ amount: CGFloat, isCritical: Bool) {
        let label = SKLabelNode(fontNamed: UIConfig.fontName)
        label.text = isCritical ? "\(Int(amount))!" : "\(Int(amount))"
        label.fontSize = isCritical ? 18 : 14
        label.fontColor = isCritical ? SKColor.yellow : SKColor.white
        label.position = CGPoint(x: 0, y: 30)
        label.zPosition = GameConfig.ZPosition.effects
        addChild(label)

        let floatUp = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: 40, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let remove = SKAction.removeFromParent()

        label.run(SKAction.sequence([SKAction.group([floatUp, fadeOut]), remove]))
    }

    private func die() {
        guard !isDead else { return }

        isDead = true
        isActive = false
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.none

        // Remove ALL actions to prevent memory leaks from repeatForever animations
        removeAllActions()

        // Also remove actions from child nodes (boss particles, fuse sparks, etc.)
        enumerateChildNodes(withName: "//*") { node, _ in
            node.removeAllActions()
        }

        // Death animation - notify delegate, then remove from scene
        let deathAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.delegate?.enemyDidDie(self)
            },
            SKAction.removeFromParent()
        ])
        run(deathAction)

        // Spawn death particles
        spawnDeathParticles()
    }

    private func spawnDeathParticles() {
        let particleCount = isElite ? 8 : (isBoss ? 16 : 4)

        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...8))
            particle.fillColor = spriteNode.fillColor
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = GameConfig.ZPosition.effects

            parent?.addChild(particle)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = CGFloat.random(in: 30...60)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.3)
            let removeAction = SKAction.removeFromParent()

            particle.run(SKAction.sequence([SKAction.group([moveAction, fadeAction]), removeAction]))
        }
    }

    // MARK: - Contact with Player

    func onContactWithPlayer() {
        guard !isDead, lastAttackTime >= attackCooldown else { return }

        lastAttackTime = 0
        delegate?.enemyDidDamagePlayer(self, damage: damage)
    }

    // MARK: - Activation

    func activate(target: Player) {
        self.target = target
        isActive = true
        isDead = false
        alpha = 1.0
        setScale(1.0)
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.enemy
    }

    func deactivate() {
        isActive = false
        target = nil
        removeAllActions()
    }

    // MARK: - Reset for Object Pool

    func reset(type: EnemyType, waveNumber: Int, isElite: Bool, isBoss: Bool) {
        // This would reinitialize the enemy for reuse
        // For simplicity, we're creating new enemies, but this can be expanded for pooling
        self.isDead = false
        self.isActive = false
        self.currentHealth = maxHealth
        self.lastAttackTime = 0
        self.alpha = 1.0
        self.setScale(1.0)

        healthBarBackground?.isHidden = true
        healthBar?.isHidden = true
        healthBar?.xScale = 1.0
    }
}

// MARK: - Enemy Factory

class EnemyFactory {

    static func createEnemy(type: EnemyType, waveNumber: Int, isElite: Bool = false, isBoss: Bool = false) -> Enemy {
        return Enemy(type: type, waveNumber: waveNumber, isElite: isElite, isBoss: isBoss)
    }

    static func createRandomEnemy(waveNumber: Int, eliteChance: CGFloat = 0) -> Enemy {
        let availableTypes: [EnemyType] = [.chaser, .swarm, .ranged, .tank]
        let randomType = availableTypes.randomElement() ?? .chaser
        let isElite = CGFloat.random(in: 0...1) < eliteChance

        return createEnemy(type: randomType, waveNumber: waveNumber, isElite: isElite)
    }

    static func createBoss(waveNumber: Int, baseType: EnemyType = .chaser) -> Enemy {
        return createEnemy(type: baseType, waveNumber: waveNumber, isElite: false, isBoss: true)
    }
}
