//
//  GameScene.swift
//  RogueWave
//
//  Main game scene containing the game loop, collision detection,
//  and coordination of all game systems
//

import SpriteKit

class GameScene: SKScene {

    // MARK: - Properties

    // Game state
    private var gameState: GameState = .menu
    private var lastUpdateTime: TimeInterval = 0
    private var gameTime: TimeInterval = 0

    // Core entities
    private var player: Player!
    private var enemies: [Enemy] = []
    private var projectiles: [Projectile] = []

    // Game systems
    private var waveManager: WaveManager!
    private var upgradeSystem: UpgradeSystem!
    private var uiManager: UIManager!

    // Input
    private var joystick: VirtualJoystick!
    private var joystickTouchZone: SKNode!

    // Scene layers
    private var gameLayer: SKNode!
    private var backgroundLayer: SKNode!
    private var worldNode: SKNode!  // Contains everything that moves with camera

    // Camera system
    private var gameCamera: SKCameraNode!

    // Infinite world system
    private var generatedChunks: Set<ChunkCoord> = []
    private var environmentObjects: [SKNode] = []
    private let chunkSize: CGFloat = 400
    private let renderDistance: Int = 2  // Chunks to render around player

    // Statistics
    private var killCount: Int = 0
    private var rerollsRemaining: Int = 0

    // Chunk coordinate helper
    private struct ChunkCoord: Hashable {
        let x: Int
        let y: Int
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        setupScene()
        setupCamera()
        setupPhysics()
        setupLayers()
        setupPlayer()
        setupJoystick()
        setupSystems()
        setupUI()

        // Generate initial world around player
        updateInfiniteWorld()

        // Start the game
        startGame()
    }

    // MARK: - Setup Methods

    private func setupScene() {
        backgroundColor = SKColor(red: 0.15, green: 0.22, blue: 0.15, alpha: 1.0)  // Dark forest green
        anchorPoint = CGPoint(x: 0.5, y: 0.5)  // Center anchor for camera

        // Initialize object pools
        ObjectPool.shared.initialize()
    }

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)
    }

    private func setupPhysics() {
        // Minimal physics for performance - no boundaries for infinite world
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func setupLayers() {
        // World node - everything that moves with the world
        worldNode = SKNode()
        worldNode.zPosition = 0
        addChild(worldNode)

        // Background layer (grass, ground tiles)
        backgroundLayer = SKNode()
        backgroundLayer.zPosition = GameConfig.ZPosition.background
        worldNode.addChild(backgroundLayer)

        // Game layer (contains player, enemies, projectiles, trees)
        gameLayer = SKNode()
        gameLayer.zPosition = GameConfig.ZPosition.floor
        worldNode.addChild(gameLayer)
    }

    // MARK: - Infinite World Generation

    private func updateInfiniteWorld() {
        let playerChunkX = Int(floor(player.position.x / chunkSize))
        let playerChunkY = Int(floor(player.position.y / chunkSize))

        // Generate chunks around player
        for dx in -renderDistance...renderDistance {
            for dy in -renderDistance...renderDistance {
                let coord = ChunkCoord(x: playerChunkX + dx, y: playerChunkY + dy)
                if !generatedChunks.contains(coord) {
                    generateChunk(at: coord)
                    generatedChunks.insert(coord)
                }
            }
        }

        // Remove distant chunks (optimization)
        let chunksToRemove = generatedChunks.filter { coord in
            abs(coord.x - playerChunkX) > renderDistance + 1 ||
            abs(coord.y - playerChunkY) > renderDistance + 1
        }

        for coord in chunksToRemove {
            removeChunk(at: coord)
            generatedChunks.remove(coord)
        }
    }

    private func generateChunk(at coord: ChunkCoord) {
        let chunkOriginX = CGFloat(coord.x) * chunkSize
        let chunkOriginY = CGFloat(coord.y) * chunkSize

        // Use seeded random for consistent generation
        srand48(coord.x * 73856093 ^ coord.y * 19349663)

        // Create ground tiles for this chunk
        let tileSize: CGFloat = 50
        let tilesPerChunk = Int(chunkSize / tileSize)

        for tx in 0..<tilesPerChunk {
            for ty in 0..<tilesPerChunk {
                let tileX = chunkOriginX + CGFloat(tx) * tileSize + tileSize / 2
                let tileY = chunkOriginY + CGFloat(ty) * tileSize + tileSize / 2

                let tile = createGroundTile(at: CGPoint(x: tileX, y: tileY), size: tileSize)
                tile.name = "chunk_\(coord.x)_\(coord.y)"
                backgroundLayer.addChild(tile)
            }
        }

        // Add environmental objects (trees, rocks, bushes)
        let objectCount = Int(drand48() * 4) + 2  // 2-5 objects per chunk

        for _ in 0..<objectCount {
            let objX = chunkOriginX + CGFloat(drand48()) * chunkSize
            let objY = chunkOriginY + CGFloat(drand48()) * chunkSize

            // Don't spawn objects too close to player start
            let distFromOrigin = sqrt(objX * objX + objY * objY)
            if distFromOrigin < 100 { continue }

            let objectType = drand48()
            let obj: SKNode

            if objectType < 0.4 {
                obj = createTree(at: CGPoint(x: objX, y: objY))
            } else if objectType < 0.7 {
                obj = createRock(at: CGPoint(x: objX, y: objY))
            } else {
                obj = createBush(at: CGPoint(x: objX, y: objY))
            }

            obj.name = "chunk_\(coord.x)_\(coord.y)"
            gameLayer.addChild(obj)
            environmentObjects.append(obj)
        }
    }

    private func removeChunk(at coord: ChunkCoord) {
        let chunkName = "chunk_\(coord.x)_\(coord.y)"

        // Remove background tiles
        backgroundLayer.children.filter { $0.name == chunkName }.forEach { $0.removeFromParent() }

        // Remove environment objects
        environmentObjects.removeAll { obj in
            if obj.name == chunkName {
                obj.removeFromParent()
                return true
            }
            return false
        }
    }

    private func createGroundTile(at position: CGPoint, size: CGFloat) -> SKNode {
        let tile = SKShapeNode(rectOf: CGSize(width: size - 1, height: size - 1))

        // Vary grass colors slightly
        let greenVariation = CGFloat(drand48()) * 0.08
        let baseGreen: CGFloat = 0.28 + greenVariation
        tile.fillColor = SKColor(red: 0.18, green: baseGreen, blue: 0.12, alpha: 1.0)
        tile.strokeColor = SKColor(red: 0.12, green: 0.2, blue: 0.08, alpha: 0.3)
        tile.lineWidth = 0.5
        tile.position = position

        // Add grass detail
        if drand48() < 0.3 {
            let grassBlade = SKShapeNode(rectOf: CGSize(width: 2, height: CGFloat(drand48()) * 8 + 4))
            grassBlade.fillColor = SKColor(red: 0.2, green: 0.4, blue: 0.15, alpha: 0.6)
            grassBlade.strokeColor = .clear
            grassBlade.position = CGPoint(
                x: CGFloat(drand48()) * size * 0.6 - size * 0.3,
                y: CGFloat(drand48()) * size * 0.6 - size * 0.3
            )
            grassBlade.zRotation = CGFloat(drand48()) * 0.3 - 0.15
            tile.addChild(grassBlade)
        }

        // Add dirt patches occasionally
        if drand48() < 0.1 {
            let dirt = SKShapeNode(circleOfRadius: CGFloat(drand48()) * 8 + 4)
            dirt.fillColor = SKColor(red: 0.25, green: 0.2, blue: 0.12, alpha: 0.5)
            dirt.strokeColor = .clear
            dirt.position = CGPoint(
                x: CGFloat(drand48()) * size * 0.5 - size * 0.25,
                y: CGFloat(drand48()) * size * 0.5 - size * 0.25
            )
            tile.addChild(dirt)
        }

        return tile
    }

    private func createTree(at position: CGPoint) -> SKNode {
        let tree = SKNode()
        tree.position = position
        tree.zPosition = GameConfig.ZPosition.enemy - 1  // Behind enemies but above ground

        // Tree trunk
        let trunkHeight: CGFloat = CGFloat(drand48()) * 20 + 30
        let trunkWidth: CGFloat = CGFloat(drand48()) * 8 + 12
        let trunk = SKShapeNode(rectOf: CGSize(width: trunkWidth, height: trunkHeight), cornerRadius: 3)
        trunk.fillColor = SKColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1.0)
        trunk.strokeColor = SKColor(red: 0.25, green: 0.18, blue: 0.1, alpha: 1.0)
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: trunkHeight / 2)
        tree.addChild(trunk)

        // Tree foliage (multiple circles for full look)
        let foliageColor = SKColor(red: 0.15, green: CGFloat(drand48()) * 0.15 + 0.35, blue: 0.12, alpha: 1.0)
        let foliageSize: CGFloat = CGFloat(drand48()) * 15 + 25

        for i in 0..<3 {
            let foliage = SKShapeNode(circleOfRadius: foliageSize - CGFloat(i) * 5)
            foliage.fillColor = foliageColor
            foliage.strokeColor = SKColor(red: 0.1, green: 0.25, blue: 0.08, alpha: 0.5)
            foliage.lineWidth = 1
            foliage.position = CGPoint(
                x: CGFloat(drand48()) * 10 - 5,
                y: trunkHeight + foliageSize * 0.5 + CGFloat(i) * 8
            )
            tree.addChild(foliage)
        }

        // Add shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: foliageSize * 1.5, height: foliageSize * 0.5))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 5, y: -5)
        shadow.zPosition = -1
        tree.addChild(shadow)

        // Add physics for collision - make it larger so player can't walk through
        // Use a larger radius based on trunk width for solid collision
        let collisionRadius = trunkWidth * 1.5
        let treeBody = SKPhysicsBody(circleOfRadius: collisionRadius)
        treeBody.isDynamic = false
        treeBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        treeBody.contactTestBitMask = GameConfig.PhysicsCategory.none
        treeBody.collisionBitMask = GameConfig.PhysicsCategory.player
        treeBody.friction = 0
        treeBody.restitution = 0
        tree.physicsBody = treeBody

        return tree
    }

    private func createRock(at position: CGPoint) -> SKNode {
        let rock = SKNode()
        rock.position = position
        rock.zPosition = GameConfig.ZPosition.enemy - 2

        let rockSize = CGFloat(drand48()) * 15 + 15

        // Rock shape (irregular)
        let rockPath = CGMutablePath()
        let points = Int(drand48() * 3) + 5
        for i in 0..<points {
            let angle = (CGFloat(i) / CGFloat(points)) * .pi * 2
            let radius = rockSize * (0.7 + CGFloat(drand48()) * 0.3)
            let x = cos(angle) * radius
            let y = sin(angle) * radius * 0.7  // Flatten slightly
            if i == 0 {
                rockPath.move(to: CGPoint(x: x, y: y))
            } else {
                rockPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        rockPath.closeSubpath()

        let rockShape = SKShapeNode(path: rockPath)
        rockShape.fillColor = SKColor(red: 0.4, green: 0.38, blue: 0.35, alpha: 1.0)
        rockShape.strokeColor = SKColor(red: 0.3, green: 0.28, blue: 0.25, alpha: 1.0)
        rockShape.lineWidth = 2
        rock.addChild(rockShape)

        // Rock highlight
        let highlight = SKShapeNode(circleOfRadius: rockSize * 0.3)
        highlight.fillColor = SKColor(red: 0.5, green: 0.48, blue: 0.45, alpha: 0.5)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -rockSize * 0.2, y: rockSize * 0.2)
        rock.addChild(highlight)

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: rockSize * 2, height: rockSize * 0.8))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.15)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -rockSize * 0.3)
        shadow.zPosition = -1
        rock.addChild(shadow)

        // Physics body - solid obstacle
        let rockBody = SKPhysicsBody(circleOfRadius: rockSize)
        rockBody.isDynamic = false
        rockBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        rockBody.contactTestBitMask = GameConfig.PhysicsCategory.none
        rockBody.collisionBitMask = GameConfig.PhysicsCategory.player
        rockBody.friction = 0
        rockBody.restitution = 0
        rock.physicsBody = rockBody

        return rock
    }

    private func createBush(at position: CGPoint) -> SKNode {
        let bush = SKNode()
        bush.position = position
        bush.zPosition = GameConfig.ZPosition.enemy - 3

        let bushSize = CGFloat(drand48()) * 10 + 12

        // Multiple overlapping circles for bush
        for i in 0..<4 {
            let leaf = SKShapeNode(circleOfRadius: bushSize - CGFloat(i) * 2)
            leaf.fillColor = SKColor(
                red: 0.2,
                green: CGFloat(drand48()) * 0.1 + 0.4,
                blue: 0.15,
                alpha: 0.9
            )
            leaf.strokeColor = SKColor(red: 0.15, green: 0.3, blue: 0.1, alpha: 0.5)
            leaf.lineWidth = 1
            leaf.position = CGPoint(
                x: CGFloat(drand48()) * bushSize * 0.5 - bushSize * 0.25,
                y: CGFloat(drand48()) * bushSize * 0.3
            )
            bush.addChild(leaf)
        }

        // Small flowers occasionally
        if drand48() < 0.3 {
            let flower = SKShapeNode(circleOfRadius: 3)
            flower.fillColor = [
                SKColor.yellow,
                SKColor.white,
                SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)
            ].randomElement()!
            flower.strokeColor = .clear
            flower.position = CGPoint(x: CGFloat(drand48()) * 10 - 5, y: bushSize * 0.5)
            bush.addChild(flower)
        }

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: bushSize * 2, height: bushSize * 0.6))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.1)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -bushSize * 0.3)
        shadow.zPosition = -1
        bush.addChild(shadow)

        // Bushes don't block movement (no physics body)
        return bush
    }

    private func setupPlayer() {
        player = Player()
        player.position = CGPoint(x: 0, y: 0)  // Start at world origin
        player.delegate = self
        gameLayer.addChild(player)

        // Position camera on player
        gameCamera.position = player.position

        // Apply permanent upgrade bonuses
        applyPermanentUpgrades()
    }

    private func applyPermanentUpgrades() {
        let healthBonus = GameManager.shared.getStartingHealthBonus()
        let damageBonus = GameManager.shared.getStartingDamageBonus()
        let speedBonus = GameManager.shared.getStartingSpeedBonus()

        player.stats.maxHealth *= healthBonus
        player.stats.currentHealth = player.stats.maxHealth
        player.stats.damage *= damageBonus
        player.stats.speed *= speedBonus

        rerollsRemaining = GameManager.shared.getRerollCount()
    }

    private func setupJoystick() {
        // Create dynamic joystick (appears where you touch)
        joystick = VirtualJoystick()
        joystick.delegate = self
        // Position relative to camera (bottom-left of screen)
        joystick.position = CGPoint(x: -size.width / 2 + UIConfig.joystickPosition.x,
                                     y: -size.height / 2 + UIConfig.joystickPosition.y)
        gameCamera.addChild(joystick)  // Add to camera so it stays on screen

        // Touch zone covers left half of screen (relative to camera)
        let touchZoneRect = CGRect(x: -size.width / 2, y: -size.height / 2,
                                    width: size.width / 2, height: size.height)
        joystickTouchZone = JoystickTouchZone(rect: touchZoneRect, joystick: joystick)
        joystickTouchZone.zPosition = GameConfig.ZPosition.ui - 1
        gameCamera.addChild(joystickTouchZone)  // Add to camera so it stays on screen
    }

    private func setupSystems() {
        // Wave manager - spawn bounds will be updated dynamically around player
        waveManager = WaveManager()
        waveManager.delegate = self
        updateSpawnBoundsAroundPlayer()

        // Upgrade system
        upgradeSystem = UpgradeSystem()
    }

    private func updateSpawnBoundsAroundPlayer() {
        // Create spawn bounds centered on player position
        // Spawn just outside screen so enemies are quickly visible and in range
        let spawnRadius: CGFloat = 280
        waveManager.spawnBounds = CGRect(
            x: player.position.x - spawnRadius,
            y: player.position.y - spawnRadius,
            width: spawnRadius * 2,
            height: spawnRadius * 2
        )
    }

    private func setupUI() {
        uiManager = UIManager(scene: self)
        uiManager.delegate = self
    }

    // MARK: - Game Flow

    private func startGame() {
        gameState = .playing
        GameManager.shared.startNewRun()

        // Reset state
        killCount = 0
        gameTime = 0
        enemies.removeAll()
        projectiles.removeAll()

        // Start first wave
        waveManager.reset()
        waveManager.startNextWave()

        // Update UI
        uiManager.updateHealth(current: player.stats.currentHealth, max: player.stats.maxHealth)
        uiManager.updateXP(current: player.stats.currentXP, max: player.stats.xpToNextLevel, level: player.stats.level)
        uiManager.updateKillCount(killCount)
    }

    private func pauseGame() {
        guard gameState == .playing else { return }

        gameState = .paused
        isPaused = true
        uiManager.showPauseScreen()
    }

    private func resumeGame() {
        guard gameState == .paused else { return }

        gameState = .playing
        isPaused = false
    }

    private func gameOver() {
        gameState = .gameOver

        // End run and save stats
        GameManager.shared.updateSurvivedTime(gameTime)
        GameManager.shared.endRun()

        // Create stats for death screen
        let stats = GameStats(
            wavesCompleted: waveManager.currentWave,
            enemiesKilled: killCount,
            damageDealt: Int(GameManager.shared.currentRunStats.damageDealt),
            timeSurvived: gameTime,
            upgradesCollected: upgradeSystem.getAcquiredUpgradesList().count
        )

        uiManager.showDeathScreen(stats: stats)
    }

    private func restartGame() {
        // Clean up
        cleanupGameObjects()
        cleanupWorld()

        // Reset player at origin
        player.reset(at: CGPoint(x: 0, y: 0))
        applyPermanentUpgrades()

        // Reset camera
        gameCamera.position = player.position

        // Regenerate world around player
        updateInfiniteWorld()

        // Reset systems
        upgradeSystem.resetForNewRun()
        uiManager.reset()

        // Start new game
        startGame()
    }

    private func cleanupWorld() {
        // Remove all generated chunks
        backgroundLayer.removeAllChildren()
        for obj in environmentObjects {
            obj.removeFromParent()
        }
        environmentObjects.removeAll()
        generatedChunks.removeAll()
    }

    private func cleanupGameObjects() {
        // Remove all enemies
        for enemy in enemies {
            enemy.removeFromParent()
        }
        enemies.removeAll()

        // Remove all projectiles
        for projectile in projectiles {
            projectile.removeFromParent()
        }
        projectiles.removeAll()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        guard gameState == .playing else { return }

        gameTime += deltaTime

        // Update game systems
        updatePlayer(deltaTime: deltaTime)
        updateCamera()
        updateInfiniteWorld()
        updateSpawnBoundsAroundPlayer()
        updateEnemies(deltaTime: deltaTime)
        updateProjectiles(deltaTime: deltaTime)
        updateWaveManager(deltaTime: deltaTime)

        // Update statistics
        GameManager.shared.updateSurvivedTime(gameTime)
    }

    private func updateCamera() {
        // Smooth camera follow
        let lerpFactor: CGFloat = 0.1
        let targetPos = player.position

        gameCamera.position.x += (targetPos.x - gameCamera.position.x) * lerpFactor
        gameCamera.position.y += (targetPos.y - gameCamera.position.y) * lerpFactor
    }

    private func updatePlayer(deltaTime: TimeInterval) {
        player.update(deltaTime: deltaTime, enemies: enemies)

        // Update ability cooldowns in UI
        if player.abilities.hasDash {
            uiManager.updateAbilityCooldown(.dash,
                remaining: player.abilities.dashCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.dash)
        }
        if player.abilities.hasAOE {
            uiManager.updateAbilityCooldown(.aoeBlast,
                remaining: player.abilities.aoeCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.aoe)
        }
        if player.abilities.hasShield {
            uiManager.updateAbilityCooldown(.shield,
                remaining: player.abilities.shieldCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.shield)
        }
    }

    private func updateEnemies(deltaTime: TimeInterval) {
        for enemy in enemies {
            enemy.update(deltaTime: deltaTime)
        }

        // Remove dead enemies
        enemies.removeAll { enemy in
            if enemy.isDead && enemy.parent == nil {
                return true
            }
            return false
        }
    }

    private func updateProjectiles(deltaTime: TimeInterval) {
        var projectilesToRemove: [Projectile] = []

        for projectile in projectiles {
            projectile.update(deltaTime: deltaTime, enemies: projectile.isPlayerProjectile ? enemies : nil)

            // Check bounds
            if !projectile.isActive || projectile.isOutOfBounds(bounds: frame) {
                projectilesToRemove.append(projectile)
            }
        }

        // Remove inactive projectiles
        for projectile in projectilesToRemove {
            projectile.removeFromParent()
            projectiles.removeAll { $0 === projectile }
        }
    }

    private func updateWaveManager(deltaTime: TimeInterval) {
        waveManager.update(deltaTime: deltaTime, currentEnemyCount: enemies.count)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check UI first
        if uiManager.handleTouch(at: location) {
            return
        }

        // Right side of screen for abilities (if not using joystick)
        if location.x > size.width / 2 {
            // Tap to use abilities (in order of priority)
            if player.abilities.hasDash && player.abilities.dashCooldownRemaining <= 0 {
                player.activateDash(direction: joystick.currentDirection)
            } else if player.abilities.hasAOE && player.abilities.aoeCooldownRemaining <= 0 {
                activateAOE()
            } else if player.abilities.hasShield && player.abilities.shieldCooldownRemaining <= 0 {
                player.activateShield()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Joystick handles its own touch tracking
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Joystick handles its own touch tracking
    }

    // MARK: - AOE Ability

    private func activateAOE() {
        player.activateAOE()

        // Deal damage to all enemies in range
        let aoeRadius: CGFloat = 150
        let aoeDamage = player.stats.damage * 2

        for enemy in enemies {
            let dx = enemy.position.x - player.position.x
            let dy = enemy.position.y - player.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= aoeRadius {
                enemy.takeDamage(aoeDamage)
                GameManager.shared.recordDamageDealt(Int(aoeDamage))
            }
        }

        GameManager.shared.recordAbilityUsed()
    }

    // MARK: - Wave Completion

    private func showUpgradeSelection() {
        gameState = .upgradeSelection

        // Update available upgrades based on wave
        upgradeSystem.updateAvailablePool(forWave: waveManager.currentWave)

        // Generate choices
        let choices = upgradeSystem.generateUpgradeChoices()

        uiManager.showUpgradeSelection(choices: choices)
    }

    private func continueAfterUpgrade() {
        gameState = .playing

        // Start next wave
        waveManager.startNextWave()
    }
}

// MARK: - SKPhysicsContactDelegate

extension GameScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // Player hit by enemy
        if collision == GameConfig.PhysicsCategory.player | GameConfig.PhysicsCategory.enemy {
            handlePlayerEnemyCollision(contact)
        }

        // Player projectile hits enemy
        if collision == GameConfig.PhysicsCategory.playerProjectile | GameConfig.PhysicsCategory.enemy {
            handleProjectileEnemyCollision(contact)
        }

        // Enemy projectile hits player
        if collision == GameConfig.PhysicsCategory.enemyProjectile | GameConfig.PhysicsCategory.player {
            handleEnemyProjectilePlayerCollision(contact)
        }
    }

    private func handlePlayerEnemyCollision(_ contact: SKPhysicsContact) {
        let enemyNode = contact.bodyA.categoryBitMask == GameConfig.PhysicsCategory.enemy ?
            contact.bodyA.node : contact.bodyB.node

        guard let enemy = enemyNode as? Enemy else { return }

        enemy.onContactWithPlayer()
    }

    private func handleProjectileEnemyCollision(_ contact: SKPhysicsContact) {
        let projectileNode = contact.bodyA.categoryBitMask == GameConfig.PhysicsCategory.playerProjectile ?
            contact.bodyA.node : contact.bodyB.node
        let enemyNode = contact.bodyA.categoryBitMask == GameConfig.PhysicsCategory.enemy ?
            contact.bodyA.node : contact.bodyB.node

        guard let projectile = projectileNode as? Projectile,
              let enemy = enemyNode as? Enemy,
              projectile.isActive, !enemy.isDead else { return }

        // Deal damage
        enemy.takeDamage(projectile.damage, isCritical: projectile.isCritical)
        GameManager.shared.recordDamageDealt(Int(projectile.damage))

        if projectile.isCritical {
            GameManager.shared.recordCriticalHit()
        }

        // Apply life steal
        player.applyLifeSteal(from: projectile.damage)

        // Handle projectile
        projectile.onHit()
    }

    private func handleEnemyProjectilePlayerCollision(_ contact: SKPhysicsContact) {
        let projectileNode = contact.bodyA.categoryBitMask == GameConfig.PhysicsCategory.enemyProjectile ?
            contact.bodyA.node : contact.bodyB.node

        guard let projectile = projectileNode as? Projectile,
              projectile.isActive else { return }

        player.takeDamage(projectile.damage)
        projectile.deactivate()
    }
}

// MARK: - PlayerDelegate

extension GameScene: PlayerDelegate {

    func playerDidShoot(projectile: Projectile) {
        gameLayer.addChild(projectile)
        projectiles.append(projectile)
    }

    func playerDidTakeDamage(amount: CGFloat) {
        uiManager.updateHealth(current: player.stats.currentHealth, max: player.stats.maxHealth)
        GameManager.shared.recordDamageTaken(Int(amount))

        // Screen shake effect
        let shakeAction = SKAction.sequence([
            SKAction.moveBy(x: -3, y: 0, duration: 0.02),
            SKAction.moveBy(x: 6, y: 0, duration: 0.02),
            SKAction.moveBy(x: -6, y: 0, duration: 0.02),
            SKAction.moveBy(x: 3, y: 0, duration: 0.02)
        ])
        gameLayer.run(shakeAction)
    }

    func playerDidDie() {
        gameOver()
    }

    func playerDidLevelUp(newLevel: Int) {
        uiManager.updateXP(current: player.stats.currentXP, max: player.stats.xpToNextLevel, level: newLevel)

        // Level up effect
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = SKColor.white.withAlphaComponent(0.3)
        flash.strokeColor = .clear
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = GameConfig.ZPosition.effects
        addChild(flash)

        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    func playerDidUseAbility(_ ability: UpgradeType) {
        GameManager.shared.recordAbilityUsed()
    }
}

// MARK: - VirtualJoystickDelegate

extension GameScene: VirtualJoystickDelegate {

    func joystickDidMove(direction: CGVector) {
        player.setMovementDirection(direction)
    }

    func joystickDidEnd() {
        player.setMovementDirection(.zero)
    }
}

// MARK: - WaveManagerDelegate

extension GameScene: WaveManagerDelegate {

    func waveDidStart(wave: Int, data: WaveData) {
        uiManager.updateWave(wave)

        // Show wave start notification
        showWaveNotification(wave: wave, modifiers: data.modifiers, isBoss: data.isBossWave)
    }

    func waveDidEnd(wave: Int, data: WaveData) {
        GameManager.shared.recordWaveCompleted()
    }

    func shouldSpawnEnemy(type: EnemyType, isElite: Bool, isBoss: Bool) -> Enemy? {
        let enemy = EnemyFactory.createEnemy(
            type: type,
            waveNumber: waveManager.currentWave,
            isElite: isElite,
            isBoss: isBoss
        )

        enemy.position = waveManager.generateSpawnPosition()
        enemy.delegate = self
        enemy.activate(target: player)

        gameLayer.addChild(enemy)
        enemies.append(enemy)

        return enemy
    }

    func waveTimerUpdated(timeRemaining: TimeInterval) {
        uiManager.updateTimer(timeRemaining)
    }

    func allEnemiesDefeated() {
        // End current wave
        waveManager.endWave()

        // Show upgrade selection
        showUpgradeSelection()
    }

    private func showWaveNotification(wave: Int, modifiers: [WaveModifier], isBoss: Bool) {
        let notification = SKNode()
        notification.position = CGPoint(x: size.width / 2, y: size.height / 2)
        notification.zPosition = GameConfig.ZPosition.effects

        // Wave text
        let waveText = SKLabelNode(fontNamed: UIConfig.fontName)
        waveText.text = isBoss ? "BOSS WAVE \(wave)" : "WAVE \(wave)"
        waveText.fontSize = 40
        waveText.fontColor = isBoss ? .red : .white
        notification.addChild(waveText)

        // Modifier text
        if !modifiers.isEmpty {
            let modifierText = SKLabelNode(fontNamed: UIConfig.fontName)
            modifierText.text = modifiers.map { $0.displayName }.joined(separator: " + ")
            modifierText.fontSize = 20
            modifierText.fontColor = SKColor.yellow
            modifierText.position = CGPoint(x: 0, y: -40)
            notification.addChild(modifierText)
        }

        addChild(notification)

        // Animate
        notification.setScale(0.5)
        notification.alpha = 0

        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        notification.run(SKAction.sequence([
            SKAction.group([fadeIn, scaleUp]),
            scaleDown,
            wait,
            fadeOut,
            remove
        ]))
    }
}

// MARK: - EnemyDelegate

extension GameScene: EnemyDelegate {

    func enemyDidDie(_ enemy: Enemy) {
        killCount += 1
        uiManager.updateKillCount(killCount)
        GameManager.shared.recordKill()

        // Grant XP to player
        let xpMultiplier = GameManager.shared.getXPMultiplier()
        let xp = Int(CGFloat(enemy.xpValue) * xpMultiplier)
        player.gainXP(xp)
        GameManager.shared.recordXPGained(enemy.xpValue)

        // Update XP bar
        uiManager.updateXP(current: player.stats.currentXP, max: player.stats.xpToNextLevel, level: player.stats.level)

        // Notify wave manager
        waveManager.enemyWasKilled()
    }

    func enemyDidShoot(_ enemy: Enemy, projectile: Projectile) {
        gameLayer.addChild(projectile)
        projectiles.append(projectile)
    }

    func enemyDidDamagePlayer(_ enemy: Enemy, damage: CGFloat) {
        player.takeDamage(damage, from: enemy)
    }
}

// MARK: - UIManagerDelegate

extension GameScene: UIManagerDelegate {

    func upgradeSelected(_ upgrade: Upgrade) {
        // Apply upgrade to player
        upgradeSystem.acquireUpgrade(upgrade)
        player.applyUpgrade(upgrade)
        GameManager.shared.recordUpgradeCollected()

        // Add ability button if needed
        if upgrade.type.isActive {
            uiManager.addAbilityButton(for: upgrade.type)
        }

        // Continue game
        continueAfterUpgrade()
    }

    func pauseButtonPressed() {
        if gameState == .playing {
            pauseGame()
        } else if gameState == .paused {
            resumeGame()
        }
    }

    func restartButtonPressed() {
        restartGame()
    }

    func mainMenuButtonPressed() {
        // For now, just restart
        restartGame()
    }

    func abilityButtonPressed(_ ability: UpgradeType) {
        switch ability {
        case .dash:
            player.activateDash(direction: joystick.currentDirection)
        case .aoeBlast:
            activateAOE()
        case .shield:
            player.activateShield()
        default:
            break
        }
    }
}

// MARK: - Notification Handling

extension GameScene {

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        // Update wave manager bounds
        waveManager?.spawnBounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }
}
