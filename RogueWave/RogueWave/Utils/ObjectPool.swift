//
//  ObjectPool.swift
//  RogueWave
//
//  Object pooling system for efficient memory management and performance
//

import SpriteKit

// MARK: - Poolable Protocol

protocol Poolable: SKNode {
    var isPooled: Bool { get set }
    func prepareForReuse()
    func returnToPool()
}

// MARK: - Generic Object Pool

class GenericPool<T: Poolable> {

    // MARK: - Properties

    private var availableObjects: [T] = []
    private var activeObjects: Set<T> = []
    private let factory: () -> T
    private let initialSize: Int
    private let maxSize: Int

    // Statistics
    private(set) var totalCreated: Int = 0
    private(set) var peakUsage: Int = 0

    // MARK: - Initialization

    init(initialSize: Int = 10, maxSize: Int = 100, factory: @escaping () -> T) {
        self.initialSize = initialSize
        self.maxSize = maxSize
        self.factory = factory

        // Pre-populate pool
        prewarm()
    }

    // MARK: - Pool Operations

    private func prewarm() {
        for _ in 0..<initialSize {
            let object = factory()
            object.isPooled = true
            availableObjects.append(object)
            totalCreated += 1
        }
    }

    func acquire() -> T {
        let object: T

        if let available = availableObjects.popLast() {
            object = available
        } else if totalCreated < maxSize {
            object = factory()
            totalCreated += 1
        } else {
            // Pool exhausted, force create but log warning
            print("Warning: Object pool exhausted, creating overflow object")
            object = factory()
            totalCreated += 1
        }

        object.isPooled = false
        object.prepareForReuse()
        activeObjects.insert(object)

        // Track peak usage
        if activeObjects.count > peakUsage {
            peakUsage = activeObjects.count
        }

        return object
    }

    func release(_ object: T) {
        guard activeObjects.contains(object) else { return }

        activeObjects.remove(object)
        object.isPooled = true
        object.returnToPool()

        if availableObjects.count < maxSize {
            availableObjects.append(object)
        }
    }

    func releaseAll() {
        for object in activeObjects {
            object.isPooled = true
            object.returnToPool()
            availableObjects.append(object)
        }
        activeObjects.removeAll()
    }

    func clear() {
        releaseAll()
        availableObjects.removeAll()
        totalCreated = 0
        peakUsage = 0
    }

    // MARK: - Info

    var activeCount: Int {
        return activeObjects.count
    }

    var availableCount: Int {
        return availableObjects.count
    }
}

// MARK: - Object Pool Manager (Singleton)

class ObjectPool {

    // MARK: - Singleton

    static let shared = ObjectPool()

    private init() {}

    // MARK: - Pools

    private var projectilePool: GenericPool<PooledProjectile>?
    private var enemyPools: [EnemyType: GenericPool<PooledEnemy>] = [:]
    private var particlePool: GenericPool<PooledParticle>?

    // MARK: - Initialization

    func initialize() {
        // Initialize projectile pool
        projectilePool = GenericPool(initialSize: 50, maxSize: 200) {
            PooledProjectile()
        }

        // Initialize enemy pools for each type
        for type in EnemyType.allCases {
            let poolSize: Int
            switch type {
            case .swarm:
                poolSize = 30
            case .chaser:
                poolSize = 20
            case .ranged, .tank:
                poolSize = 10
            case .elite, .boss:
                poolSize = 5
            }

            enemyPools[type] = GenericPool(initialSize: poolSize, maxSize: poolSize * 3) {
                PooledEnemy(type: type)
            }
        }

        // Initialize particle pool
        particlePool = GenericPool(initialSize: 100, maxSize: 500) {
            PooledParticle()
        }
    }

    // MARK: - Projectile Pool

    func acquireProjectile() -> PooledProjectile? {
        return projectilePool?.acquire()
    }

    func releaseProjectile(_ projectile: PooledProjectile) {
        projectilePool?.release(projectile)
    }

    // MARK: - Enemy Pool

    func acquireEnemy(type: EnemyType) -> PooledEnemy? {
        return enemyPools[type]?.acquire()
    }

    func releaseEnemy(_ enemy: PooledEnemy) {
        enemyPools[enemy.pooledType]?.release(enemy)
    }

    // MARK: - Particle Pool

    func acquireParticle() -> PooledParticle? {
        return particlePool?.acquire()
    }

    func releaseParticle(_ particle: PooledParticle) {
        particlePool?.release(particle)
    }

    // MARK: - Clear All

    func clearAllPools() {
        projectilePool?.clear()
        for pool in enemyPools.values {
            pool.clear()
        }
        particlePool?.clear()
    }

    // MARK: - Statistics

    func getPoolStatistics() -> [String: (active: Int, available: Int, peak: Int)] {
        var stats: [String: (active: Int, available: Int, peak: Int)] = [:]

        if let pool = projectilePool {
            stats["Projectiles"] = (pool.activeCount, pool.availableCount, pool.peakUsage)
        }

        for (type, pool) in enemyPools {
            stats["Enemy_\(type.rawValue)"] = (pool.activeCount, pool.availableCount, pool.peakUsage)
        }

        if let pool = particlePool {
            stats["Particles"] = (pool.activeCount, pool.availableCount, pool.peakUsage)
        }

        return stats
    }
}

// MARK: - Pooled Projectile

class PooledProjectile: SKNode, Poolable {

    var isPooled: Bool = true

    private var spriteNode: SKShapeNode!
    var damage: CGFloat = 0
    var moveSpeed: CGFloat = 0
    var isPlayerProjectile: Bool = true
    var piercing: Bool = false
    var homing: Bool = false
    var isCritical: Bool = false
    var isActive: Bool = false

    override init() {
        super.init()
        setupVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisuals() {
        spriteNode = SKShapeNode(circleOfRadius: 6)
        spriteNode.fillColor = .cyan
        spriteNode.strokeColor = .white
        spriteNode.lineWidth = 1
        addChild(spriteNode)

        let body = SKPhysicsBody(circleOfRadius: 6)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = GameConfig.PhysicsCategory.playerProjectile
        body.contactTestBitMask = GameConfig.PhysicsCategory.enemy
        body.collisionBitMask = GameConfig.PhysicsCategory.none
        body.linearDamping = 0
        physicsBody = body

        zPosition = GameConfig.ZPosition.projectile
    }

    func configure(damage: CGFloat, speed: CGFloat, angle: CGFloat,
                   isPlayerProjectile: Bool, piercing: Bool, homing: Bool, isCritical: Bool) {
        self.damage = damage
        self.moveSpeed = speed
        self.isPlayerProjectile = isPlayerProjectile
        self.piercing = piercing
        self.homing = homing
        self.isCritical = isCritical
        self.isActive = true

        // Update visuals
        spriteNode.fillColor = isPlayerProjectile ?
            (isCritical ? .yellow : .cyan) : .red
        spriteNode.glowWidth = isCritical ? 8 : 4

        // Update physics
        if isPlayerProjectile {
            physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.playerProjectile
            physicsBody?.contactTestBitMask = GameConfig.PhysicsCategory.enemy
        } else {
            physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.enemyProjectile
            physicsBody?.contactTestBitMask = GameConfig.PhysicsCategory.player
        }

        // Apply velocity
        let vx = cos(angle) * moveSpeed
        let vy = sin(angle) * moveSpeed
        physicsBody?.velocity = CGVector(dx: vx, dy: vy)
    }

    func prepareForReuse() {
        isActive = false
        alpha = 1.0
        setScale(1.0)
        position = .zero
        physicsBody?.velocity = .zero
        removeAllActions()
    }

    func returnToPool() {
        isActive = false
        removeFromParent()
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.none
    }
}

// MARK: - Pooled Enemy

class PooledEnemy: SKNode, Poolable {

    var isPooled: Bool = true
    let pooledType: EnemyType

    private var spriteNode: SKShapeNode!
    var maxHealth: CGFloat = 0
    var currentHealth: CGFloat = 0
    var moveSpeed: CGFloat = 0
    var damage: CGFloat = 0
    var isDead: Bool = false
    var isActive: Bool = false

    init(type: EnemyType) {
        self.pooledType = type
        super.init()
        setupVisuals(for: type)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisuals(for type: EnemyType) {
        let size: CGFloat = 30
        spriteNode = SKShapeNode(circleOfRadius: size / 2)
        spriteNode.fillColor = .red
        spriteNode.strokeColor = .white
        spriteNode.lineWidth = 2
        addChild(spriteNode)

        let body = SKPhysicsBody(circleOfRadius: size / 2)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = GameConfig.PhysicsCategory.enemy
        body.contactTestBitMask = GameConfig.PhysicsCategory.player | GameConfig.PhysicsCategory.playerProjectile
        body.collisionBitMask = GameConfig.PhysicsCategory.boundary
        body.linearDamping = 3.0
        physicsBody = body

        zPosition = GameConfig.ZPosition.enemy
    }

    func configure(health: CGFloat, speed: CGFloat, damage: CGFloat, color: SKColor) {
        self.maxHealth = health
        self.currentHealth = health
        self.moveSpeed = speed
        self.damage = damage
        self.isDead = false
        self.isActive = true

        spriteNode.fillColor = color
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.enemy
    }

    func prepareForReuse() {
        isDead = false
        isActive = false
        alpha = 1.0
        setScale(1.0)
        position = .zero
        physicsBody?.velocity = .zero
        removeAllActions()
    }

    func returnToPool() {
        isActive = false
        isDead = true
        removeFromParent()
        physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.none
    }
}

// MARK: - Pooled Particle

class PooledParticle: SKNode, Poolable {

    var isPooled: Bool = true

    private var shapeNode: SKShapeNode!

    override init() {
        super.init()
        setupVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisuals() {
        shapeNode = SKShapeNode(circleOfRadius: 5)
        shapeNode.fillColor = .white
        shapeNode.strokeColor = .clear
        addChild(shapeNode)

        zPosition = GameConfig.ZPosition.effects
    }

    func configure(color: SKColor, size: CGFloat) {
        shapeNode.fillColor = color
        let scale = size / 5.0
        setScale(scale)
    }

    func prepareForReuse() {
        alpha = 1.0
        setScale(1.0)
        position = .zero
        removeAllActions()
    }

    func returnToPool() {
        removeFromParent()
    }
}
