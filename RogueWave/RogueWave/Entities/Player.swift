//
//  Player.swift
//  RogueWave
//
//  Player entity with movement, combat, stats, and upgrades
//

import SpriteKit

// MARK: - Player Stats Structure

struct PlayerStats {
    var maxHealth: CGFloat = PlayerConfig.baseHealth
    var currentHealth: CGFloat = PlayerConfig.baseHealth
    var speed: CGFloat = PlayerConfig.baseSpeed
    var damage: CGFloat = PlayerConfig.baseDamage
    var attackSpeed: CGFloat = PlayerConfig.baseAttackSpeed
    var attackRange: CGFloat = PlayerConfig.baseAttackRange
    var projectileSpeed: CGFloat = PlayerConfig.baseProjectileSpeed
    var critChance: CGFloat = PlayerConfig.baseCritChance
    var critMultiplier: CGFloat = PlayerConfig.baseCritMultiplier
    var armor: CGFloat = 0
    var lifeSteal: CGFloat = 0
    var projectileCount: Int = 1
    var hasPiercing: Bool = false
    var hasHoming: Bool = false

    // Experience
    var level: Int = 1
    var currentXP: Int = 0
    var xpToNextLevel: Int = PlayerConfig.baseXPToLevel

    mutating func reset() {
        maxHealth = PlayerConfig.baseHealth
        currentHealth = PlayerConfig.baseHealth
        speed = PlayerConfig.baseSpeed
        damage = PlayerConfig.baseDamage
        attackSpeed = PlayerConfig.baseAttackSpeed
        attackRange = PlayerConfig.baseAttackRange
        projectileSpeed = PlayerConfig.baseProjectileSpeed
        critChance = PlayerConfig.baseCritChance
        critMultiplier = PlayerConfig.baseCritMultiplier
        armor = 0
        lifeSteal = 0
        projectileCount = 1
        hasPiercing = false
        hasHoming = false
        level = 1
        currentXP = 0
        xpToNextLevel = PlayerConfig.baseXPToLevel
    }
}

// MARK: - Player Abilities

struct PlayerAbilities {
    var hasDash: Bool = false
    var hasAOE: Bool = false
    var hasShield: Bool = false

    var dashCooldownRemaining: TimeInterval = 0
    var aoeCooldownRemaining: TimeInterval = 0
    var shieldCooldownRemaining: TimeInterval = 0

    var isShieldActive: Bool = false
    var shieldDuration: TimeInterval = 3.0

    mutating func reset() {
        hasDash = false
        hasAOE = false
        hasShield = false
        dashCooldownRemaining = 0
        aoeCooldownRemaining = 0
        shieldCooldownRemaining = 0
        isShieldActive = false
    }
}

// MARK: - Player Delegate Protocol

protocol PlayerDelegate: AnyObject {
    func playerDidShoot(projectile: Projectile)
    func playerDidTakeDamage(amount: CGFloat)
    func playerDidDie()
    func playerDidLevelUp(newLevel: Int)
    func playerDidUseAbility(_ ability: UpgradeType)
}

// MARK: - Player Class

class Player: SKNode {

    // MARK: - Properties

    weak var delegate: PlayerDelegate?

    // Visual components
    private var spriteNode: SKShapeNode!
    private var shieldNode: SKShapeNode?

    // Stats and abilities
    var stats = PlayerStats()
    var abilities = PlayerAbilities()

    // State
    var isInvincible: Bool = false
    var isDead: Bool = false
    private var lastAttackTime: TimeInterval = 0
    private var movementVector: CGVector = .zero

    // Attack target
    weak var currentTarget: Enemy?

    // MARK: - Initialization

    override init() {
        super.init()
        setupVisuals()
        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupVisuals() {
        // Main player sprite (circle shape)
        spriteNode = SKShapeNode(circleOfRadius: PlayerConfig.size / 2)
        spriteNode.fillColor = PlayerConfig.color
        spriteNode.strokeColor = SKColor.white
        spriteNode.lineWidth = 2
        spriteNode.glowWidth = 3
        addChild(spriteNode)

        // Direction indicator
        let indicator = SKShapeNode(rectOf: CGSize(width: 8, height: PlayerConfig.size / 2))
        indicator.fillColor = SKColor.white.withAlphaComponent(0.8)
        indicator.strokeColor = .clear
        indicator.position = CGPoint(x: 0, y: PlayerConfig.size / 4)
        spriteNode.addChild(indicator)

        zPosition = GameConfig.ZPosition.player
    }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: PlayerConfig.size / 2)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.PhysicsCategory.player
        body.contactTestBitMask = GameConfig.PhysicsCategory.enemy | GameConfig.PhysicsCategory.enemyProjectile | GameConfig.PhysicsCategory.pickup
        body.collisionBitMask = GameConfig.PhysicsCategory.boundary
        body.linearDamping = 5.0
        physicsBody = body
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, enemies: [Enemy]) {
        guard !isDead else { return }

        // Update cooldowns
        updateCooldowns(deltaTime: deltaTime)

        // Apply movement
        applyMovement()

        // Auto-attack nearest enemy
        autoAttack(deltaTime: deltaTime, enemies: enemies)

        // Update shield
        if abilities.isShieldActive {
            updateShield(deltaTime: deltaTime)
        }
    }

    private func updateCooldowns(deltaTime: TimeInterval) {
        if abilities.dashCooldownRemaining > 0 {
            abilities.dashCooldownRemaining -= deltaTime
        }
        if abilities.aoeCooldownRemaining > 0 {
            abilities.aoeCooldownRemaining -= deltaTime
        }
        if abilities.shieldCooldownRemaining > 0 {
            abilities.shieldCooldownRemaining -= deltaTime
        }
    }

    // MARK: - Movement

    func setMovementDirection(_ direction: CGVector) {
        movementVector = direction
    }

    private func applyMovement() {
        guard movementVector != .zero else {
            physicsBody?.velocity = .zero
            return
        }

        // Normalize and apply speed
        let length = sqrt(movementVector.dx * movementVector.dx + movementVector.dy * movementVector.dy)
        let normalizedX = movementVector.dx / length
        let normalizedY = movementVector.dy / length

        physicsBody?.velocity = CGVector(
            dx: normalizedX * stats.speed,
            dy: normalizedY * stats.speed
        )

        // Rotate player to face movement direction
        let angle = atan2(movementVector.dy, movementVector.dx) - .pi / 2
        spriteNode.zRotation = angle
    }

    // MARK: - Combat

    private func autoAttack(deltaTime: TimeInterval, enemies: [Enemy]) {
        guard !enemies.isEmpty else { return }

        lastAttackTime += deltaTime
        let attackInterval = 1.0 / stats.attackSpeed

        guard lastAttackTime >= attackInterval else { return }

        // Find nearest enemy in range
        let nearestEnemy = findNearestEnemy(enemies: enemies)
        guard let target = nearestEnemy,
              distanceTo(target) <= stats.attackRange else { return }

        currentTarget = target
        lastAttackTime = 0

        // Fire projectile(s)
        fireProjectiles(at: target)
    }

    private func findNearestEnemy(enemies: [Enemy]) -> Enemy? {
        var nearestEnemy: Enemy?
        var nearestDistance: CGFloat = .greatestFiniteMagnitude

        for enemy in enemies {
            guard !enemy.isDead else { continue }
            let distance = distanceTo(enemy)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEnemy = enemy
            }
        }

        return nearestEnemy
    }

    private func distanceTo(_ node: SKNode) -> CGFloat {
        let dx = node.position.x - position.x
        let dy = node.position.y - position.y
        return sqrt(dx * dx + dy * dy)
    }

    private func fireProjectiles(at target: Enemy) {
        let baseAngle = angleTo(target)

        // Calculate spread for multiple projectiles
        let spreadAngle: CGFloat = stats.projectileCount > 1 ? .pi / 12 : 0
        let startAngle = baseAngle - spreadAngle * CGFloat(stats.projectileCount - 1) / 2

        for i in 0..<stats.projectileCount {
            let angle = startAngle + spreadAngle * CGFloat(i)
            let projectile = createProjectile(angle: angle)
            delegate?.playerDidShoot(projectile: projectile)
        }

        // Visual feedback - slight recoil
        let recoilAction = SKAction.sequence([
            SKAction.scale(to: 0.9, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.05)
        ])
        spriteNode.run(recoilAction)
    }

    private func createProjectile(angle: CGFloat) -> Projectile {
        // Calculate damage with crit
        var damage = stats.damage
        var isCrit = false

        if CGFloat.random(in: 0...1) < stats.critChance {
            damage *= stats.critMultiplier
            isCrit = true
        }

        let projectile = Projectile(
            damage: damage,
            speed: stats.projectileSpeed,
            angle: angle,
            isPlayerProjectile: true,
            piercing: stats.hasPiercing,
            homing: stats.hasHoming,
            isCritical: isCrit
        )

        projectile.position = position
        return projectile
    }

    private func angleTo(_ node: SKNode) -> CGFloat {
        let dx = node.position.x - position.x
        let dy = node.position.y - position.y
        return atan2(dy, dx)
    }

    // MARK: - Damage and Health

    func takeDamage(_ amount: CGFloat, from source: SKNode? = nil) {
        guard !isInvincible && !isDead && !abilities.isShieldActive else { return }

        // Apply armor reduction
        let reducedDamage = max(1, amount - stats.armor)
        stats.currentHealth -= reducedDamage

        delegate?.playerDidTakeDamage(amount: reducedDamage)

        // Hit feedback
        showHitFeedback()

        // Brief invincibility
        startInvincibility()

        // Check death
        if stats.currentHealth <= 0 {
            die()
        }
    }

    func heal(_ amount: CGFloat) {
        stats.currentHealth = min(stats.currentHealth + amount, stats.maxHealth)
    }

    func applyLifeSteal(from damage: CGFloat) {
        if stats.lifeSteal > 0 {
            let healAmount = damage * stats.lifeSteal
            heal(healAmount)
        }
    }

    private func showHitFeedback() {
        // Flash red
        let flashAction = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.spriteNode.fillColor = SKColor.red
            },
            SKAction.wait(forDuration: PlayerConfig.hitFlashDuration),
            SKAction.run { [weak self] in
                self?.spriteNode.fillColor = PlayerConfig.color
            }
        ])
        run(flashAction)

        // Shake effect
        let shakeAction = SKAction.sequence([
            SKAction.moveBy(x: -5, y: 0, duration: 0.02),
            SKAction.moveBy(x: 10, y: 0, duration: 0.02),
            SKAction.moveBy(x: -10, y: 0, duration: 0.02),
            SKAction.moveBy(x: 5, y: 0, duration: 0.02)
        ])
        run(shakeAction)
    }

    private func startInvincibility() {
        isInvincible = true

        // Flashing effect during invincibility
        let flashSequence = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        let flashAction = SKAction.repeat(flashSequence, count: Int(PlayerConfig.invincibilityDuration / 0.2))

        run(flashAction) { [weak self] in
            self?.isInvincible = false
            self?.alpha = 1.0
        }
    }

    private func die() {
        isDead = true
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.none

        // Death animation
        let deathAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.run { [weak self] in
                self?.delegate?.playerDidDie()
            }
        ])
        run(deathAction)
    }

    // MARK: - Experience

    func gainXP(_ amount: Int) {
        stats.currentXP += amount

        while stats.currentXP >= stats.xpToNextLevel {
            levelUp()
        }
    }

    private func levelUp() {
        stats.currentXP -= stats.xpToNextLevel
        stats.level += 1
        stats.xpToNextLevel = Int(CGFloat(PlayerConfig.baseXPToLevel) * pow(PlayerConfig.xpScalingFactor, CGFloat(stats.level - 1)))

        // Level up effects
        let pulseAction = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        run(pulseAction)

        // Glow effect
        spriteNode.glowWidth = 10
        let glowAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.spriteNode.glowWidth = 3
            }
        ])
        run(glowAction)

        delegate?.playerDidLevelUp(newLevel: stats.level)
    }

    // MARK: - Abilities

    func activateDash(direction: CGVector) {
        guard abilities.hasDash && abilities.dashCooldownRemaining <= 0 else { return }

        abilities.dashCooldownRemaining = UpgradeConfig.AbilityCooldowns.dash

        // Dash distance and speed
        let dashDistance: CGFloat = 150
        var dashDirection = direction

        // If no direction, dash in facing direction
        if dashDirection == .zero {
            let angle = spriteNode.zRotation + .pi / 2
            dashDirection = CGVector(dx: cos(angle), dy: sin(angle))
        }

        // Normalize
        let length = sqrt(dashDirection.dx * dashDirection.dx + dashDirection.dy * dashDirection.dy)
        let normalizedDirection = CGVector(
            dx: dashDirection.dx / length * dashDistance,
            dy: dashDirection.dy / length * dashDistance
        )

        // Make invincible during dash
        isInvincible = true

        // Dash action with trail effect
        let dashAction = SKAction.sequence([
            SKAction.moveBy(x: normalizedDirection.dx, y: normalizedDirection.dy, duration: 0.15),
            SKAction.run { [weak self] in
                self?.isInvincible = false
            }
        ])

        run(dashAction)
        createDashTrail()

        delegate?.playerDidUseAbility(.dash)
    }

    private func createDashTrail() {
        for i in 0..<3 {
            let trail = SKShapeNode(circleOfRadius: PlayerConfig.size / 2)
            trail.fillColor = PlayerConfig.color.withAlphaComponent(0.5 - CGFloat(i) * 0.15)
            trail.strokeColor = .clear
            trail.position = position
            trail.zPosition = zPosition - 1

            parent?.addChild(trail)

            let delay = TimeInterval(i) * 0.05
            let fadeAction = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ])
            trail.run(fadeAction)
        }
    }

    func activateAOE() {
        guard abilities.hasAOE && abilities.aoeCooldownRemaining <= 0 else { return }

        abilities.aoeCooldownRemaining = UpgradeConfig.AbilityCooldowns.aoe

        // Create AOE blast visual
        let blastRadius: CGFloat = 150
        let blast = SKShapeNode(circleOfRadius: blastRadius)
        blast.fillColor = SKColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 0.3)
        blast.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.8)
        blast.lineWidth = 3
        blast.position = .zero
        blast.setScale(0.1)
        addChild(blast)

        // Expand and fade
        let expandAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        blast.run(expandAction)

        delegate?.playerDidUseAbility(.aoeBlast)
    }

    func activateShield() {
        guard abilities.hasShield && abilities.shieldCooldownRemaining <= 0 else { return }

        abilities.shieldCooldownRemaining = UpgradeConfig.AbilityCooldowns.shield
        abilities.isShieldActive = true

        // Create shield visual
        shieldNode = SKShapeNode(circleOfRadius: PlayerConfig.size / 2 + 10)
        shieldNode?.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.3)
        shieldNode?.strokeColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.8)
        shieldNode?.lineWidth = 3
        shieldNode?.glowWidth = 5
        addChild(shieldNode!)

        delegate?.playerDidUseAbility(.shield)
    }

    private func updateShield(deltaTime: TimeInterval) {
        abilities.shieldDuration -= deltaTime

        if abilities.shieldDuration <= 0 {
            deactivateShield()
        }
    }

    private func deactivateShield() {
        abilities.isShieldActive = false
        abilities.shieldDuration = 3.0

        shieldNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        shieldNode = nil
    }

    // MARK: - Upgrades

    func applyUpgrade(_ upgrade: Upgrade) {
        switch upgrade.type {
        case .maxHealth:
            let bonus = UpgradeConfig.PassiveValues.healthBonus * CGFloat(upgrade.level)
            stats.maxHealth += bonus
            stats.currentHealth += bonus

        case .moveSpeed:
            stats.speed += UpgradeConfig.PassiveValues.speedBonus * CGFloat(upgrade.level)

        case .damage:
            stats.damage += UpgradeConfig.PassiveValues.damageBonus * CGFloat(upgrade.level)

        case .attackSpeed:
            stats.attackSpeed += UpgradeConfig.PassiveValues.attackSpeedBonus * CGFloat(upgrade.level)

        case .critChance:
            stats.critChance += UpgradeConfig.PassiveValues.critChanceBonus * CGFloat(upgrade.level)

        case .critDamage:
            stats.critMultiplier += UpgradeConfig.PassiveValues.critDamageBonus * CGFloat(upgrade.level)

        case .attackRange:
            stats.attackRange += UpgradeConfig.PassiveValues.rangeBonus * CGFloat(upgrade.level)

        case .projectileSpeed:
            stats.projectileSpeed += UpgradeConfig.PassiveValues.projectileSpeedBonus * CGFloat(upgrade.level)

        case .armor:
            stats.armor += 5 * CGFloat(upgrade.level)

        case .lifeSteal:
            stats.lifeSteal += 0.03 * CGFloat(upgrade.level)

        case .dash:
            abilities.hasDash = true

        case .aoeBlast:
            abilities.hasAOE = true

        case .shield:
            abilities.hasShield = true

        case .multishot:
            stats.projectileCount += 1

        case .piercing:
            stats.hasPiercing = true

        case .homing:
            stats.hasHoming = true
        }
    }

    // MARK: - Reset

    func reset(at position: CGPoint) {
        self.position = position
        stats.reset()
        abilities.reset()
        isDead = false
        isInvincible = false
        alpha = 1.0
        setScale(1.0)
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.player
        spriteNode.fillColor = PlayerConfig.color

        shieldNode?.removeFromParent()
        shieldNode = nil
    }
}
