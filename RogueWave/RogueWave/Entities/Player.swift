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
    var armor: CGFloat = 0  // No starting armor - skill based!
    var lifeSteal: CGFloat = 0  // No life steal - dodge to survive!
    var projectileCount: Int = 3  // Start with triple shot
    var hasPiercing: Bool = true  // Projectiles pierce through enemies
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
        armor = 0  // No starting armor - skill based!
        lifeSteal = 0  // No life steal - dodge to survive!
        projectileCount = 3  // Start with triple shot
        hasPiercing = true  // Projectiles pierce through enemies
        hasHoming = false
        level = 1
        currentXP = 0
        xpToNextLevel = PlayerConfig.baseXPToLevel
    }
}

// MARK: - Player Abilities

struct PlayerAbilities {
    // Basic abilities
    var hasDash: Bool = false
    var hasAOE: Bool = false
    var hasShield: Bool = false

    // Advanced abilities (wave 5+)
    var hasTimeSlow: Bool = false
    var hasTeleport: Bool = false
    var hasReflect: Bool = false
    var hasVortex: Bool = false

    // Cooldowns
    var dashCooldownRemaining: TimeInterval = 0
    var aoeCooldownRemaining: TimeInterval = 0
    var shieldCooldownRemaining: TimeInterval = 0
    var timeSlowCooldownRemaining: TimeInterval = 0
    var teleportCooldownRemaining: TimeInterval = 0
    var reflectCooldownRemaining: TimeInterval = 0
    var vortexCooldownRemaining: TimeInterval = 0

    // Active states
    var isShieldActive: Bool = false
    var shieldDuration: TimeInterval = 3.0
    var isTimeSlowActive: Bool = false
    var timeSlowDuration: TimeInterval = 3.0
    var isReflectActive: Bool = false
    var reflectDuration: TimeInterval = 2.0

    mutating func reset() {
        hasDash = false
        hasAOE = false
        hasShield = false
        hasTimeSlow = false
        hasTeleport = false
        hasReflect = false
        hasVortex = false
        dashCooldownRemaining = 0
        aoeCooldownRemaining = 0
        shieldCooldownRemaining = 0
        timeSlowCooldownRemaining = 0
        teleportCooldownRemaining = 0
        reflectCooldownRemaining = 0
        vortexCooldownRemaining = 0
        isShieldActive = false
        isTimeSlowActive = false
        isReflectActive = false
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

    // Momentum-based movement
    private var currentVelocity: CGVector = .zero
    private let acceleration: CGFloat = 15.0  // How fast we accelerate
    private let deceleration: CGFloat = 10.0  // How fast we slow down
    private let maxSpeedMultiplier: CGFloat = 1.0  // Max velocity as multiplier of stats.speed

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
        // Create heroic champion knight
        let size = PlayerConfig.size

        // Main body container
        spriteNode = SKShapeNode()
        addChild(spriteNode)

        // Cape (behind everything)
        let capePath = CGMutablePath()
        capePath.move(to: CGPoint(x: -size * 0.25, y: size * 0.1))
        capePath.addQuadCurve(to: CGPoint(x: -size * 0.35, y: -size * 0.5),
                               control: CGPoint(x: -size * 0.45, y: -size * 0.2))
        capePath.addLine(to: CGPoint(x: size * 0.35, y: -size * 0.5))
        capePath.addQuadCurve(to: CGPoint(x: size * 0.25, y: size * 0.1),
                               control: CGPoint(x: size * 0.45, y: -size * 0.2))
        capePath.closeSubpath()
        let cape = SKShapeNode(path: capePath)
        cape.fillColor = SKColor(red: 0.7, green: 0.15, blue: 0.15, alpha: 1.0) // Royal red
        cape.strokeColor = SKColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 1.0)
        cape.lineWidth = 1
        cape.zPosition = -1
        spriteNode.addChild(cape)

        // Armored body
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -size * 0.28, y: -size * 0.35))
        bodyPath.addLine(to: CGPoint(x: -size * 0.32, y: size * 0.05))
        bodyPath.addLine(to: CGPoint(x: -size * 0.2, y: size * 0.2))
        bodyPath.addLine(to: CGPoint(x: size * 0.2, y: size * 0.2))
        bodyPath.addLine(to: CGPoint(x: size * 0.32, y: size * 0.05))
        bodyPath.addLine(to: CGPoint(x: size * 0.28, y: -size * 0.35))
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = SKColor(red: 0.75, green: 0.75, blue: 0.8, alpha: 1.0) // Silver armor
        body.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
        body.lineWidth = 2
        spriteNode.addChild(body)

        // Chest plate detail
        let chestPlate = SKShapeNode(rectOf: CGSize(width: size * 0.35, height: size * 0.25), cornerRadius: 3)
        chestPlate.fillColor = SKColor(red: 0.25, green: 0.45, blue: 0.7, alpha: 1.0) // Blue accent
        chestPlate.strokeColor = SKColor(red: 0.8, green: 0.75, blue: 0.5, alpha: 1.0) // Gold trim
        chestPlate.lineWidth = 2
        chestPlate.position = CGPoint(x: 0, y: -size * 0.05)
        body.addChild(chestPlate)

        // Golden lion emblem on chest
        let emblem = SKShapeNode(circleOfRadius: size * 0.08)
        emblem.fillColor = SKColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1.0)
        emblem.strokeColor = SKColor(red: 0.7, green: 0.6, blue: 0.2, alpha: 1.0)
        emblem.lineWidth = 1
        emblem.glowWidth = 2
        chestPlate.addChild(emblem)

        // Helmet with face guard
        let helmetPath = CGMutablePath()
        helmetPath.move(to: CGPoint(x: -size * 0.22, y: -size * 0.05))
        helmetPath.addLine(to: CGPoint(x: -size * 0.25, y: size * 0.15))
        helmetPath.addQuadCurve(to: CGPoint(x: 0, y: size * 0.32),
                                 control: CGPoint(x: -size * 0.2, y: size * 0.35))
        helmetPath.addQuadCurve(to: CGPoint(x: size * 0.25, y: size * 0.15),
                                 control: CGPoint(x: size * 0.2, y: size * 0.35))
        helmetPath.addLine(to: CGPoint(x: size * 0.22, y: -size * 0.05))
        helmetPath.closeSubpath()

        let helmet = SKShapeNode(path: helmetPath)
        helmet.fillColor = SKColor(red: 0.8, green: 0.8, blue: 0.85, alpha: 1.0)
        helmet.strokeColor = SKColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1.0)
        helmet.lineWidth = 2
        helmet.position = CGPoint(x: 0, y: size * 0.15)
        spriteNode.addChild(helmet)

        // Visor (T-shaped opening)
        let visorV = SKShapeNode(rectOf: CGSize(width: size * 0.06, height: size * 0.18))
        visorV.fillColor = SKColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0)
        visorV.strokeColor = .clear
        visorV.position = CGPoint(x: 0, y: -size * 0.02)
        helmet.addChild(visorV)

        let visorH = SKShapeNode(rectOf: CGSize(width: size * 0.28, height: size * 0.05))
        visorH.fillColor = SKColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0)
        visorH.strokeColor = .clear
        visorH.position = CGPoint(x: 0, y: size * 0.03)
        helmet.addChild(visorH)

        // Glowing eyes through visor
        let leftEyeGlow = SKShapeNode(circleOfRadius: size * 0.025)
        leftEyeGlow.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        leftEyeGlow.strokeColor = .clear
        leftEyeGlow.glowWidth = 4
        leftEyeGlow.position = CGPoint(x: -size * 0.06, y: size * 0.03)
        helmet.addChild(leftEyeGlow)

        let rightEyeGlow = SKShapeNode(circleOfRadius: size * 0.025)
        rightEyeGlow.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        rightEyeGlow.strokeColor = .clear
        rightEyeGlow.glowWidth = 4
        rightEyeGlow.position = CGPoint(x: size * 0.06, y: size * 0.03)
        helmet.addChild(rightEyeGlow)

        // Majestic plume
        let plumePath = CGMutablePath()
        plumePath.move(to: CGPoint(x: 0, y: size * 0.15))
        plumePath.addQuadCurve(to: CGPoint(x: -size * 0.12, y: size * 0.5),
                                control: CGPoint(x: -size * 0.2, y: size * 0.35))
        plumePath.addQuadCurve(to: CGPoint(x: 0, y: size * 0.45),
                                control: CGPoint(x: -size * 0.05, y: size * 0.55))
        plumePath.addQuadCurve(to: CGPoint(x: size * 0.12, y: size * 0.5),
                                control: CGPoint(x: size * 0.05, y: size * 0.55))
        plumePath.addQuadCurve(to: CGPoint(x: 0, y: size * 0.15),
                                control: CGPoint(x: size * 0.2, y: size * 0.35))
        plumePath.closeSubpath()

        let plume = SKShapeNode(path: plumePath)
        plume.fillColor = SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)
        plume.strokeColor = SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0)
        plume.lineWidth = 1
        helmet.addChild(plume)

        // Glowing sword (right side, pointing up)
        let bladePath = CGMutablePath()
        bladePath.move(to: CGPoint(x: 0, y: size * 0.6))
        bladePath.addLine(to: CGPoint(x: -size * 0.05, y: size * 0.15))
        bladePath.addLine(to: CGPoint(x: size * 0.05, y: size * 0.15))
        bladePath.closeSubpath()

        let blade = SKShapeNode(path: bladePath)
        blade.fillColor = SKColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        blade.strokeColor = SKColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1.0)
        blade.lineWidth = 1
        blade.glowWidth = 6
        blade.position = CGPoint(x: size * 0.38, y: 0)
        spriteNode.addChild(blade)

        // Sword crossguard
        let crossguard = SKShapeNode(rectOf: CGSize(width: size * 0.2, height: size * 0.05), cornerRadius: 2)
        crossguard.fillColor = SKColor(red: 0.85, green: 0.75, blue: 0.3, alpha: 1.0)
        crossguard.strokeColor = SKColor(red: 0.65, green: 0.55, blue: 0.2, alpha: 1.0)
        crossguard.lineWidth = 1
        crossguard.position = CGPoint(x: 0, y: size * 0.15)
        blade.addChild(crossguard)

        // Sword handle
        let handle = SKShapeNode(rectOf: CGSize(width: size * 0.05, height: size * 0.12))
        handle.fillColor = SKColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1.0)
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 0, y: size * 0.08)
        blade.addChild(handle)

        // Sword pommel
        let pommel = SKShapeNode(circleOfRadius: size * 0.04)
        pommel.fillColor = SKColor(red: 0.85, green: 0.75, blue: 0.3, alpha: 1.0)
        pommel.strokeColor = .clear
        pommel.position = CGPoint(x: 0, y: size * 0.01)
        blade.addChild(pommel)

        // Shield (left side)
        let shieldPath = CGMutablePath()
        shieldPath.move(to: CGPoint(x: 0, y: size * 0.25))
        shieldPath.addLine(to: CGPoint(x: -size * 0.18, y: size * 0.15))
        shieldPath.addLine(to: CGPoint(x: -size * 0.2, y: -size * 0.1))
        shieldPath.addLine(to: CGPoint(x: 0, y: -size * 0.28))
        shieldPath.addLine(to: CGPoint(x: size * 0.08, y: -size * 0.05))
        shieldPath.addLine(to: CGPoint(x: size * 0.06, y: size * 0.15))
        shieldPath.closeSubpath()

        let shield = SKShapeNode(path: shieldPath)
        shield.fillColor = SKColor(red: 0.25, green: 0.45, blue: 0.7, alpha: 1.0) // Blue shield
        shield.strokeColor = SKColor(red: 0.85, green: 0.75, blue: 0.35, alpha: 1.0) // Gold border
        shield.lineWidth = 3
        shield.position = CGPoint(x: -size * 0.32, y: 0)
        spriteNode.addChild(shield)

        // Shield emblem - golden lion
        let lionHead = SKShapeNode(circleOfRadius: size * 0.08)
        lionHead.fillColor = SKColor(red: 0.9, green: 0.8, blue: 0.35, alpha: 1.0)
        lionHead.strokeColor = SKColor(red: 0.7, green: 0.6, blue: 0.25, alpha: 1.0)
        lionHead.lineWidth = 1
        lionHead.position = CGPoint(x: -size * 0.05, y: 0)
        shield.addChild(lionHead)

        // Shoulder pauldrons
        let leftPauldron = SKShapeNode(ellipseOf: CGSize(width: size * 0.2, height: size * 0.15))
        leftPauldron.fillColor = SKColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
        leftPauldron.strokeColor = SKColor(red: 0.85, green: 0.75, blue: 0.35, alpha: 1.0)
        leftPauldron.lineWidth = 2
        leftPauldron.position = CGPoint(x: -size * 0.28, y: size * 0.12)
        spriteNode.addChild(leftPauldron)

        let rightPauldron = SKShapeNode(ellipseOf: CGSize(width: size * 0.2, height: size * 0.15))
        rightPauldron.fillColor = SKColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
        rightPauldron.strokeColor = SKColor(red: 0.85, green: 0.75, blue: 0.35, alpha: 1.0)
        rightPauldron.lineWidth = 2
        rightPauldron.position = CGPoint(x: size * 0.28, y: size * 0.12)
        spriteNode.addChild(rightPauldron)

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

        // Update ability states
        if abilities.isShieldActive {
            updateShield(deltaTime: deltaTime)
        }
        if abilities.isTimeSlowActive {
            updateTimeSlow(deltaTime: deltaTime)
        }
        if abilities.isReflectActive {
            updateReflect(deltaTime: deltaTime)
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
        if abilities.timeSlowCooldownRemaining > 0 {
            abilities.timeSlowCooldownRemaining -= deltaTime
        }
        if abilities.teleportCooldownRemaining > 0 {
            abilities.teleportCooldownRemaining -= deltaTime
        }
        if abilities.reflectCooldownRemaining > 0 {
            abilities.reflectCooldownRemaining -= deltaTime
        }
        if abilities.vortexCooldownRemaining > 0 {
            abilities.vortexCooldownRemaining -= deltaTime
        }
    }

    // MARK: - Movement

    func setMovementDirection(_ direction: CGVector) {
        movementVector = direction
    }

    private func applyMovement() {
        let maxSpeed = stats.speed * maxSpeedMultiplier

        if movementVector != .zero {
            // Normalize input
            let length = sqrt(movementVector.dx * movementVector.dx + movementVector.dy * movementVector.dy)
            let normalizedX = movementVector.dx / length
            let normalizedY = movementVector.dy / length

            // Target velocity based on input
            let targetVelocity = CGVector(
                dx: normalizedX * maxSpeed,
                dy: normalizedY * maxSpeed
            )

            // Smooth acceleration toward target velocity
            currentVelocity.dx += (targetVelocity.dx - currentVelocity.dx) * acceleration * 0.016
            currentVelocity.dy += (targetVelocity.dy - currentVelocity.dy) * acceleration * 0.016

            // Rotate player to face movement direction
            let angle = atan2(movementVector.dy, movementVector.dx) - .pi / 2
            spriteNode.zRotation = angle
        } else {
            // Smooth deceleration when no input
            currentVelocity.dx *= (1.0 - deceleration * 0.016)
            currentVelocity.dy *= (1.0 - deceleration * 0.016)

            // Stop completely when very slow
            let currentSpeed = sqrt(currentVelocity.dx * currentVelocity.dx + currentVelocity.dy * currentVelocity.dy)
            if currentSpeed < 5 {
                currentVelocity = .zero
            }
        }

        // Clamp to max speed
        let currentSpeed = sqrt(currentVelocity.dx * currentVelocity.dx + currentVelocity.dy * currentVelocity.dy)
        if currentSpeed > maxSpeed {
            let scale = maxSpeed / currentSpeed
            currentVelocity.dx *= scale
            currentVelocity.dy *= scale
        }

        physicsBody?.velocity = currentVelocity
    }

    // MARK: - Combat

    // Track last attack direction for continuous shooting
    private var lastAttackAngle: CGFloat = .pi / 2  // Default: shoot upward

    private func autoAttack(deltaTime: TimeInterval, enemies: [Enemy]) {
        lastAttackTime += deltaTime
        let attackInterval = 1.0 / stats.attackSpeed

        guard lastAttackTime >= attackInterval else { return }

        // Always shoot! Find best direction
        if let target = findNearestEnemy(enemies: enemies, includeDead: false) {
            // Found a live enemy - shoot at it
            currentTarget = target
            lastAttackAngle = angleTo(target)
        } else if let target = findNearestEnemy(enemies: enemies, includeDead: true) {
            // Only dead enemies - shoot toward where they are
            lastAttackAngle = angleTo(target)
        } else if movementVector != .zero {
            // No enemies - shoot in movement direction
            lastAttackAngle = atan2(movementVector.dy, movementVector.dx)
        }
        // Otherwise keep using lastAttackAngle (previous direction)

        // Always fire!
        lastAttackTime = 0
        fireProjectilesAtAngle(lastAttackAngle)
    }

    private func findNearestEnemy(enemies: [Enemy], includeDead: Bool) -> Enemy? {
        var nearestEnemy: Enemy?
        var nearestDistance: CGFloat = .greatestFiniteMagnitude

        for enemy in enemies {
            if !includeDead && enemy.isDead { continue }
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
        fireProjectilesAtAngle(baseAngle)
    }

    private func fireProjectilesAtAngle(_ baseAngle: CGFloat) {
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
        // Cancel any existing hit feedback to prevent action accumulation
        removeAction(forKey: "hitFlash")
        removeAction(forKey: "hitShake")

        // Flash red - use key to prevent stacking
        let flashAction = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.spriteNode.fillColor = SKColor.red
            },
            SKAction.wait(forDuration: PlayerConfig.hitFlashDuration),
            SKAction.run { [weak self] in
                self?.spriteNode.fillColor = PlayerConfig.color
            }
        ])
        run(flashAction, withKey: "hitFlash")

        // Shake effect - use key to prevent stacking
        let shakeAction = SKAction.sequence([
            SKAction.moveBy(x: -5, y: 0, duration: 0.02),
            SKAction.moveBy(x: 10, y: 0, duration: 0.02),
            SKAction.moveBy(x: -10, y: 0, duration: 0.02),
            SKAction.moveBy(x: 5, y: 0, duration: 0.02)
        ])
        run(shakeAction, withKey: "hitShake")
    }

    private func startInvincibility() {
        isInvincible = true

        // Cancel any existing invincibility flash to prevent stacking
        removeAction(forKey: "invincibilityFlash")

        // Flashing effect during invincibility - use key to prevent stacking
        let flashSequence = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        let flashAction = SKAction.repeat(flashSequence, count: Int(PlayerConfig.invincibilityDuration / 0.2))

        let fullAction = SKAction.sequence([
            flashAction,
            SKAction.run { [weak self] in
                self?.isInvincible = false
                self?.alpha = 1.0
            }
        ])
        run(fullAction, withKey: "invincibilityFlash")
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

    // MARK: - Advanced Abilities (Wave 5+)

    func activateTimeSlow() {
        guard abilities.hasTimeSlow && abilities.timeSlowCooldownRemaining <= 0 else { return }

        abilities.timeSlowCooldownRemaining = UpgradeConfig.AbilityCooldowns.timeSlow
        abilities.isTimeSlowActive = true
        abilities.timeSlowDuration = 3.0

        // Purple time distortion visual
        let timeField = SKShapeNode(circleOfRadius: 300)
        timeField.fillColor = SKColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 0.15)
        timeField.strokeColor = SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 0.6)
        timeField.lineWidth = 3
        timeField.glowWidth = 10
        timeField.name = "timeField"
        addChild(timeField)

        // Pulsing effect
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        timeField.run(pulse)

        delegate?.playerDidUseAbility(.timeSlow)
    }

    private func updateTimeSlow(deltaTime: TimeInterval) {
        abilities.timeSlowDuration -= deltaTime

        if abilities.timeSlowDuration <= 0 {
            deactivateTimeSlow()
        }
    }

    private func deactivateTimeSlow() {
        abilities.isTimeSlowActive = false
        abilities.timeSlowDuration = 3.0

        if let timeField = childNode(withName: "timeField") {
            // CRITICAL: Remove repeatForever pulse action before removing node
            timeField.removeAllActions()
            timeField.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
    }

    func activateTeleport(direction: CGVector) {
        guard abilities.hasTeleport && abilities.teleportCooldownRemaining <= 0 else { return }

        abilities.teleportCooldownRemaining = UpgradeConfig.AbilityCooldowns.teleport

        // Teleport distance
        let teleportDistance: CGFloat = 200
        var teleportDirection = direction

        // If no direction, teleport in facing direction
        if teleportDirection == .zero {
            let angle = spriteNode.zRotation + .pi / 2
            teleportDirection = CGVector(dx: cos(angle), dy: sin(angle))
        }

        // Normalize
        let length = sqrt(teleportDirection.dx * teleportDirection.dx + teleportDirection.dy * teleportDirection.dy)
        guard length > 0 else { return }

        let targetX = position.x + (teleportDirection.dx / length) * teleportDistance
        let targetY = position.y + (teleportDirection.dy / length) * teleportDistance

        // Vanish effect at start position
        let vanishEffect = SKShapeNode(circleOfRadius: PlayerConfig.size)
        vanishEffect.fillColor = SKColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 0.5)
        vanishEffect.strokeColor = .clear
        vanishEffect.position = position
        vanishEffect.zPosition = GameConfig.ZPosition.effects
        parent?.addChild(vanishEffect)

        vanishEffect.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ]))

        // Instant teleport with brief invincibility
        isInvincible = true
        position = CGPoint(x: targetX, y: targetY)

        // Appear effect at new position
        let appearEffect = SKShapeNode(circleOfRadius: PlayerConfig.size * 2)
        appearEffect.fillColor = SKColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 0.5)
        appearEffect.strokeColor = .clear
        appearEffect.position = position
        appearEffect.zPosition = GameConfig.ZPosition.effects
        parent?.addChild(appearEffect)

        appearEffect.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.1, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.run { [weak self] in
                self?.isInvincible = false
            },
            SKAction.removeFromParent()
        ]))

        delegate?.playerDidUseAbility(.teleport)
    }

    func activateReflect() {
        guard abilities.hasReflect && abilities.reflectCooldownRemaining <= 0 else { return }

        abilities.reflectCooldownRemaining = UpgradeConfig.AbilityCooldowns.reflect
        abilities.isReflectActive = true
        abilities.reflectDuration = 2.0

        // Golden reflective barrier
        let reflectShield = SKShapeNode(circleOfRadius: PlayerConfig.size + 15)
        reflectShield.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.2)
        reflectShield.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.9)
        reflectShield.lineWidth = 4
        reflectShield.glowWidth = 8
        reflectShield.name = "reflectShield"
        addChild(reflectShield)

        // Spinning effect
        let spin = SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 1.0))
        reflectShield.run(spin)

        delegate?.playerDidUseAbility(.reflect)
    }

    private func updateReflect(deltaTime: TimeInterval) {
        abilities.reflectDuration -= deltaTime

        if abilities.reflectDuration <= 0 {
            deactivateReflect()
        }
    }

    private func deactivateReflect() {
        abilities.isReflectActive = false
        abilities.reflectDuration = 2.0

        if let reflectShield = childNode(withName: "reflectShield") {
            // CRITICAL: Remove repeatForever spin action before removing node
            reflectShield.removeAllActions()
            reflectShield.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
        }
    }

    func activateVortex() {
        guard abilities.hasVortex && abilities.vortexCooldownRemaining <= 0 else { return }

        abilities.vortexCooldownRemaining = UpgradeConfig.AbilityCooldowns.vortex

        // Create vortex visual
        let vortex = SKShapeNode(circleOfRadius: 20)
        vortex.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.5, alpha: 0.6)
        vortex.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.9)
        vortex.lineWidth = 3
        vortex.glowWidth = 10
        vortex.position = .zero
        vortex.name = "vortex"
        addChild(vortex)

        // Expand with spinning
        let expandAndSpin = SKAction.group([
            SKAction.scale(to: 8, duration: 1.0),
            SKAction.rotate(byAngle: .pi * 4, duration: 1.0)
        ])

        // Then explode
        let explode = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 12, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ])

        vortex.run(SKAction.sequence([expandAndSpin, explode]))

        delegate?.playerDidUseAbility(.vortex)
    }

    // MARK: - Upgrades

    func applyUpgrade(_ upgrade: Upgrade) {
        // Note: Each upgrade is applied once per selection, so we only add the base bonus
        // (not multiplied by level - the level just tracks how many times we've picked this upgrade)
        switch upgrade.type {
        case .maxHealth:
            let bonus = UpgradeConfig.PassiveValues.healthBonus
            stats.maxHealth += bonus
            stats.currentHealth += bonus

        case .moveSpeed:
            stats.speed += UpgradeConfig.PassiveValues.speedBonus

        case .damage:
            stats.damage += UpgradeConfig.PassiveValues.damageBonus

        case .attackSpeed:
            stats.attackSpeed += UpgradeConfig.PassiveValues.attackSpeedBonus

        case .critChance:
            stats.critChance += UpgradeConfig.PassiveValues.critChanceBonus

        case .critDamage:
            stats.critMultiplier += UpgradeConfig.PassiveValues.critDamageBonus

        case .attackRange:
            stats.attackRange += UpgradeConfig.PassiveValues.rangeBonus

        case .projectileSpeed:
            stats.projectileSpeed += UpgradeConfig.PassiveValues.projectileSpeedBonus

        case .armor:
            stats.armor += 5

        case .lifeSteal:
            stats.lifeSteal += 0.03

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

        // Advanced abilities (wave 5+)
        case .timeSlow:
            abilities.hasTimeSlow = true

        case .teleport:
            abilities.hasTeleport = true

        case .reflect:
            abilities.hasReflect = true

        case .vortex:
            abilities.hasVortex = true
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
