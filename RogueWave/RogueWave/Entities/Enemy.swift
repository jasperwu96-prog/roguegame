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

    // Target reference
    weak var target: Player?

    // MARK: - Initialization

    init(type: EnemyType, waveNumber: Int = 1, isElite: Bool = false, isBoss: Bool = false) {
        self.enemyType = type
        self.isElite = isElite
        self.isBoss = isBoss

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

        case .swarm:
            baseHealth = EnemyConfig.Swarm.baseHealth
            baseSpeed = EnemyConfig.Swarm.baseSpeed
            baseDamage = EnemyConfig.Swarm.baseDamage
            baseXP = EnemyConfig.Swarm.xpValue
            size = EnemyConfig.Swarm.size
            color = EnemyConfig.Swarm.color

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
        // Create sprite based on enemy type
        switch enemyType {
        case .chaser, .elite, .boss:
            // Triangle shape for chasers
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: -size / 2, y: -size / 2))
            path.addLine(to: CGPoint(x: size / 2, y: -size / 2))
            path.closeSubpath()
            spriteNode = SKShapeNode(path: path)

        case .swarm:
            // Small circle for swarm
            spriteNode = SKShapeNode(circleOfRadius: size / 2)

        case .ranged:
            // Diamond shape for ranged
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: size / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -size / 2))
            path.addLine(to: CGPoint(x: -size / 2, y: 0))
            path.closeSubpath()
            spriteNode = SKShapeNode(path: path)

        case .tank:
            // Square shape for tank
            spriteNode = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 5)
        }

        spriteNode.fillColor = color
        spriteNode.strokeColor = SKColor.white.withAlphaComponent(0.5)
        spriteNode.lineWidth = 2
        addChild(spriteNode)
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

        // Movement and attack behavior based on type
        switch enemyType {
        case .ranged:
            updateRangedBehavior(deltaTime: deltaTime, target: target)
        default:
            updateChaserBehavior(target: target)
        }

        lastAttackTime += deltaTime
    }

    private func updateChaserBehavior(target: Player) {
        // Move toward player
        let direction = directionTo(target)
        physicsBody?.velocity = CGVector(dx: direction.x * moveSpeed, dy: direction.y * moveSpeed)

        // Rotate to face player
        let angle = atan2(direction.y, direction.x) - .pi / 2
        spriteNode.zRotation = angle
    }

    private func updateRangedBehavior(deltaTime: TimeInterval, target: Player) {
        let distanceToTarget = distanceTo(target)

        if distanceToTarget > attackRange {
            // Move closer
            let direction = directionTo(target)
            physicsBody?.velocity = CGVector(dx: direction.x * moveSpeed, dy: direction.y * moveSpeed)
        } else {
            // Stop and shoot
            physicsBody?.velocity = .zero

            if lastAttackTime >= attackCooldown {
                shoot(at: target)
                lastAttackTime = 0
            }
        }

        // Rotate to face player
        let direction = directionTo(target)
        let angle = atan2(direction.y, direction.x) - .pi / 2
        spriteNode.zRotation = angle
    }

    private func shoot(at target: Player) {
        let angle = angleTo(target)

        let projectile = Projectile(
            damage: damage,
            speed: projectileSpeed,
            angle: angle,
            isPlayerProjectile: false,
            piercing: false,
            homing: false,
            isCritical: false
        )
        projectile.position = position

        delegate?.enemyDidShoot(self, projectile: projectile)

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

        // Remove actions
        removeAction(forKey: "elitePulse")

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
