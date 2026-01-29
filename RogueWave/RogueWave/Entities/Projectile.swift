//
//  Projectile.swift
//  RogueWave
//
//  Projectile entity for player and enemy attacks
//

import SpriteKit

// MARK: - Projectile Class

class Projectile: SKNode {

    // MARK: - Properties

    private var spriteNode: SKShapeNode!

    var damage: CGFloat
    let moveSpeed: CGFloat
    let angle: CGFloat
    var isPlayerProjectile: Bool
    let piercing: Bool
    let homing: Bool
    let isCritical: Bool

    var isActive: Bool = true
    var hitCount: Int = 0
    let maxHits: Int = 3  // For piercing projectiles

    // Homing properties
    weak var homingTarget: Enemy?
    let homingStrength: CGFloat = 5.0

    // Lifetime
    var lifetime: TimeInterval = 3.0

    // MARK: - Initialization

    init(damage: CGFloat, speed: CGFloat, angle: CGFloat, isPlayerProjectile: Bool,
         piercing: Bool = false, homing: Bool = false, isCritical: Bool = false) {

        self.damage = damage
        self.moveSpeed = speed
        self.angle = angle
        self.isPlayerProjectile = isPlayerProjectile
        self.piercing = piercing
        self.homing = homing
        self.isCritical = isCritical

        super.init()

        setupVisuals()
        setupPhysics()
        applyInitialVelocity()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupVisuals() {
        // Create projectile shape based on type
        if isPlayerProjectile {
            // Player projectile - glowing circle
            spriteNode = SKShapeNode(circleOfRadius: isCritical ? 8 : 6)
            spriteNode.fillColor = isCritical ?
                SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0) :
                SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
            spriteNode.strokeColor = SKColor.white
            spriteNode.lineWidth = 1
            spriteNode.glowWidth = isCritical ? 8 : 4
        } else {
            // Enemy projectile - red diamond
            let size: CGFloat = 10
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: size / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -size / 2))
            path.addLine(to: CGPoint(x: -size / 2, y: 0))
            path.closeSubpath()

            spriteNode = SKShapeNode(path: path)
            spriteNode.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
            spriteNode.strokeColor = SKColor.white.withAlphaComponent(0.5)
            spriteNode.lineWidth = 1
            spriteNode.glowWidth = 3
        }

        addChild(spriteNode)

        // Add trail effect
        addTrailEffect()

        zPosition = GameConfig.ZPosition.projectile
    }

    private func addTrailEffect() {
        // DISABLED: Trail effects cause too many nodes and performance issues
        // Only critical projectiles get trails now (none currently)
        return
    }

    private func spawnTrailParticle() {
        guard let parentNode = parent else { return }

        let trail = SKShapeNode(circleOfRadius: 2)
        trail.fillColor = spriteNode.fillColor.withAlphaComponent(0.4)
        trail.strokeColor = .clear
        trail.position = position
        trail.zPosition = zPosition - 1

        parentNode.addChild(trail)

        let fadeAction = SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.12),
                SKAction.scale(to: 0.2, duration: 0.12)
            ]),
            SKAction.removeFromParent()
        ])
        trail.run(fadeAction)
    }

    private func setupPhysics() {
        let radius: CGFloat = isPlayerProjectile ? 6 : 5

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false

        if isPlayerProjectile {
            body.categoryBitMask = GameConfig.PhysicsCategory.playerProjectile
            body.contactTestBitMask = GameConfig.PhysicsCategory.enemy
            body.collisionBitMask = GameConfig.PhysicsCategory.none
        } else {
            body.categoryBitMask = GameConfig.PhysicsCategory.enemyProjectile
            body.contactTestBitMask = GameConfig.PhysicsCategory.player
            body.collisionBitMask = GameConfig.PhysicsCategory.none
        }

        body.linearDamping = 0
        physicsBody = body
    }

    private func applyInitialVelocity() {
        let vx = cos(angle) * moveSpeed
        let vy = sin(angle) * moveSpeed
        physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        // Rotate sprite to face direction
        spriteNode.zRotation = angle - .pi / 2
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, enemies: [Enemy]? = nil) {
        guard isActive else { return }

        // Update lifetime
        lifetime -= deltaTime
        if lifetime <= 0 {
            deactivate()
            return
        }

        // Homing behavior
        if homing && isPlayerProjectile, let enemies = enemies {
            updateHoming(enemies: enemies)
        }
    }

    private func updateHoming(enemies: [Enemy]) {
        // Find nearest enemy if no target or target is dead
        if homingTarget == nil || homingTarget?.isDead == true {
            homingTarget = findNearestEnemy(enemies: enemies)
        }

        guard let target = homingTarget else { return }

        // Calculate angle to target
        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let targetAngle = atan2(dy, dx)

        // Current velocity angle
        guard let velocity = physicsBody?.velocity else { return }
        let currentAngle = atan2(velocity.dy, velocity.dx)

        // Smoothly adjust angle toward target
        var angleDiff = targetAngle - currentAngle

        // Normalize angle difference
        while angleDiff > .pi { angleDiff -= .pi * 2 }
        while angleDiff < -.pi { angleDiff += .pi * 2 }

        let newAngle = currentAngle + angleDiff * 0.1  // Adjust turning speed

        // Apply new velocity
        let newVx = cos(newAngle) * moveSpeed
        let newVy = sin(newAngle) * moveSpeed
        physicsBody?.velocity = CGVector(dx: newVx, dy: newVy)

        // Update sprite rotation
        spriteNode.zRotation = newAngle - .pi / 2
    }

    private func findNearestEnemy(enemies: [Enemy]) -> Enemy? {
        var nearestEnemy: Enemy?
        var nearestDistance: CGFloat = .greatestFiniteMagnitude

        for enemy in enemies {
            guard !enemy.isDead else { continue }

            let dx = enemy.position.x - position.x
            let dy = enemy.position.y - position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < nearestDistance {
                nearestDistance = distance
                nearestEnemy = enemy
            }
        }

        return nearestEnemy
    }

    // MARK: - Hit Detection

    func onHit() {
        hitCount += 1

        if !piercing || hitCount >= maxHits {
            deactivate()
        } else {
            // Visual feedback for pierce
            let scaleAction = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.05),
                SKAction.scale(to: 1.0, duration: 0.05)
            ])
            spriteNode.run(scaleAction)
        }
    }

    // MARK: - Deactivation

    func deactivate() {
        guard isActive else { return }

        isActive = false
        removeAction(forKey: "trail")
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.none

        // Impact effect
        let impactAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1)
            ]),
            SKAction.removeFromParent()
        ])
        run(impactAction)
    }

    // MARK: - Reflect (for Reflect ability)

    func reflect() {
        // Reverse direction using physics body velocity
        if let velocity = physicsBody?.velocity {
            physicsBody?.velocity = CGVector(dx: -velocity.dx, dy: -velocity.dy)

            // Update sprite rotation to face new direction
            let newAngle = atan2(-velocity.dy, -velocity.dx)
            spriteNode.zRotation = newAngle - .pi / 2
        }

        // Increase damage when reflected
        damage *= 1.5

        // Mark as player projectile now
        isPlayerProjectile = true

        // Update physics category
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.playerProjectile
        physicsBody?.contactTestBitMask = GameConfig.PhysicsCategory.enemy

        // Visual change - make it glow gold
        spriteNode.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        spriteNode.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1.0)
        spriteNode.glowWidth = 8
    }

    // MARK: - Bounds Checking

    func isOutOfBounds(bounds: CGRect) -> Bool {
        let padding: CGFloat = 50
        let expandedBounds = bounds.insetBy(dx: -padding, dy: -padding)
        return !expandedBounds.contains(position)
    }
}
