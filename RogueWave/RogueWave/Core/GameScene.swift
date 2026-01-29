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

    // Character selection (set before presenting scene)
    var selectedCharacterClass: CharacterClass = .knight

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
    private var bossKillCount: Int = 0
    private var totalDamageDealt: Int = 0
    private var damageTakenThisWave: CGFloat = 0

    // Wave 10+ skill checks - danger zones
    private var lastDangerZoneTime: TimeInterval = 0
    private var dangerZones: [SKNode] = []

    // Achievement tracking
    private var waveStartTime: TimeInterval = 0

    // Screen shake tracking
    private var cameraOriginalPosition: CGPoint = .zero
    private var isShaking: Bool = false

    // Hit freeze tracking
    private var hitFreezeActive: Bool = false

    // Heal effect throttling to prevent node accumulation during rapid hits
    private var lastHealEffectTime: TimeInterval = 0
    private let healEffectThrottle: TimeInterval = 0.3  // Only show heal effect every 300ms

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
        setupAchievements()

        // Generate initial world around player
        updateInfiniteWorld()

        // Start the game
        startGame()

        // Start background music
        AudioManager.shared.playBackgroundMusic()
    }

    private func setupAchievements() {
        AchievementManager.shared.onAchievementUnlocked = { [weak self] achievement in
            self?.showAchievementUnlock(achievement)
        }
    }

    private func showAchievementUnlock(_ achievement: Achievement) {
        // Create achievement banner
        let banner = SKNode()
        banner.zPosition = GameConfig.ZPosition.overlay

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 60), cornerRadius: 10)
        bg.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.95)
        bg.strokeColor = SKColor.yellow
        bg.lineWidth = 2
        bg.glowWidth = 3
        banner.addChild(bg)

        // Trophy icon
        let trophy = SKLabelNode(fontNamed: UIConfig.fontName)
        trophy.text = "🏆"
        trophy.fontSize = 28
        trophy.position = CGPoint(x: -110, y: -8)
        banner.addChild(trophy)

        // Title
        let title = SKLabelNode(fontNamed: UIConfig.fontName)
        title.text = "Achievement Unlocked!"
        title.fontSize = 12
        title.fontColor = SKColor.yellow
        title.position = CGPoint(x: 10, y: 12)
        banner.addChild(title)

        // Achievement name
        let name = SKLabelNode(fontNamed: UIConfig.fontName)
        name.text = achievement.name
        name.fontSize = 16
        name.fontColor = SKColor.white
        name.position = CGPoint(x: 10, y: -10)
        banner.addChild(name)

        // Position at top of screen
        banner.position = CGPoint(x: 0, y: size.height / 2 + 50)
        gameCamera.addChild(banner)

        // Animate in, stay, animate out
        let moveIn = SKAction.moveTo(y: size.height / 2 - 60, duration: 0.4)
        moveIn.timingMode = .easeOut
        let wait = SKAction.wait(forDuration: 3.0)
        let moveOut = SKAction.moveTo(y: size.height / 2 + 50, duration: 0.3)
        moveOut.timingMode = .easeIn
        let remove = SKAction.removeFromParent()

        banner.run(SKAction.sequence([moveIn, wait, moveOut, remove]))

        // Play achievement sound
        AudioManager.shared.playSFX(.achievement, on: self)
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

        // Determine biome for this chunk center
        let chunkCenter = CGPoint(x: chunkOriginX + chunkSize / 2, y: chunkOriginY + chunkSize / 2)
        let biome = getBiome(at: chunkCenter)

        // Create ground tiles for this chunk
        let tileSize: CGFloat = 50
        let tilesPerChunk = Int(chunkSize / tileSize)

        for tx in 0..<tilesPerChunk {
            for ty in 0..<tilesPerChunk {
                let tileX = chunkOriginX + CGFloat(tx) * tileSize + tileSize / 2
                let tileY = chunkOriginY + CGFloat(ty) * tileSize + tileSize / 2

                let tile = createGroundTile(at: CGPoint(x: tileX, y: tileY), size: tileSize, biome: biome)
                tile.name = "chunk_\(coord.x)_\(coord.y)"
                backgroundLayer.addChild(tile)
            }
        }

        // Add environmental objects based on biome
        let objectCount = Int(drand48() * 4) + 2  // 2-5 objects per chunk

        for _ in 0..<objectCount {
            let objX = chunkOriginX + CGFloat(drand48()) * chunkSize
            let objY = chunkOriginY + CGFloat(drand48()) * chunkSize

            // Don't spawn objects too close to player start
            let distFromOrigin = sqrt(objX * objX + objY * objY)
            if distFromOrigin < 100 { continue }

            let obj = createBiomeObject(at: CGPoint(x: objX, y: objY), biome: biome)

            obj.name = "chunk_\(coord.x)_\(coord.y)"
            gameLayer.addChild(obj)
            environmentObjects.append(obj)
        }

        // Chance to spawn a structure (house, well, etc.)
        if drand48() < 0.25 {
            let structX = chunkOriginX + CGFloat(drand48()) * chunkSize * 0.6 + chunkSize * 0.2
            let structY = chunkOriginY + CGFloat(drand48()) * chunkSize * 0.6 + chunkSize * 0.2

            let distFromOrigin = sqrt(structX * structX + structY * structY)
            if distFromOrigin > 200 {
                let structure = createBiomeStructure(at: CGPoint(x: structX, y: structY), biome: biome)
                structure.name = "chunk_\(coord.x)_\(coord.y)"
                gameLayer.addChild(structure)
                environmentObjects.append(structure)
            }
        }
    }

    private func createBiomeObject(at position: CGPoint, biome: Biome) -> SKNode {
        let objectType = drand48()

        switch biome {
        case .forest:
            if objectType < 0.4 {
                return createTree(at: position)
            } else if objectType < 0.7 {
                return createRock(at: position)
            } else {
                return createBush(at: position)
            }

        case .desert:
            if objectType < 0.5 {
                return createCactus(at: position)
            } else if objectType < 0.8 {
                return createRock(at: position)
            } else {
                return createDeadBush(at: position)
            }

        case .snow:
            if objectType < 0.5 {
                return createSnowTree(at: position)
            } else if objectType < 0.8 {
                return createRock(at: position)
            } else {
                return createSnowDrift(at: position)
            }

        case .swamp:
            if objectType < 0.5 {
                return createSwampTree(at: position)
            } else if objectType < 0.75 {
                return createSwampPool(at: position)
            } else {
                return createBush(at: position)
            }

        case .ruins:
            if objectType < 0.35 {
                return createRuinPillar(at: position)
            } else if objectType < 0.6 {
                return createGravestone(at: position)
            } else if objectType < 0.8 {
                return createRock(at: position)
            } else {
                return createDeadTree(at: position)
            }
        }
    }

    private func createBiomeStructure(at position: CGPoint, biome: Biome) -> SKNode {
        let structType = drand48()

        switch biome {
        case .forest:
            if structType < 0.5 {
                return createHouse(at: position, biome: biome)
            } else if structType < 0.8 {
                return createWell(at: position)
            } else {
                return createFence(at: position, biome: biome)
            }

        case .desert:
            if structType < 0.6 {
                return createHouse(at: position, biome: biome)
            } else {
                return createWell(at: position)
            }

        case .snow:
            if structType < 0.6 {
                return createHouse(at: position, biome: biome)
            } else {
                return createFence(at: position, biome: biome)
            }

        case .swamp:
            if structType < 0.5 {
                return createHouse(at: position, biome: biome)
            } else {
                return createFence(at: position, biome: biome)
            }

        case .ruins:
            if structType < 0.4 {
                return createHouse(at: position, biome: biome)
            } else if structType < 0.7 {
                return createFence(at: position, biome: biome)
            } else {
                return createRuinPillar(at: position)
            }
        }
    }

    private func createDeadBush(at position: CGPoint) -> SKNode {
        let bush = SKNode()
        bush.position = position
        bush.zPosition = GameConfig.ZPosition.enemy - 3

        let bushColor = SKColor(red: 0.5, green: 0.42, blue: 0.3, alpha: 0.9)

        // Dead branches
        for _ in 0..<5 {
            let branchLength = CGFloat(drand48()) * 12 + 6
            let branch = SKShapeNode(rectOf: CGSize(width: 2, height: branchLength))
            branch.fillColor = bushColor
            branch.strokeColor = .clear
            branch.position = CGPoint(x: CGFloat(drand48()) * 10 - 5, y: branchLength / 2)
            branch.zRotation = CGFloat(drand48()) * 1.0 - 0.5
            bush.addChild(branch)
        }

        return bush
    }

    private func createSnowDrift(at position: CGPoint) -> SKNode {
        let drift = SKNode()
        drift.position = position
        drift.zPosition = GameConfig.ZPosition.enemy - 3

        let driftWidth = CGFloat(drand48()) * 20 + 15
        let driftHeight = CGFloat(drand48()) * 8 + 5

        let snow = SKShapeNode(ellipseOf: CGSize(width: driftWidth, height: driftHeight))
        snow.fillColor = SKColor(red: 0.92, green: 0.94, blue: 0.98, alpha: 0.9)
        snow.strokeColor = SKColor(red: 0.8, green: 0.85, blue: 0.9, alpha: 0.5)
        snow.lineWidth = 1
        drift.addChild(snow)

        // Sparkle
        if drand48() < 0.5 {
            let sparkle = SKShapeNode(circleOfRadius: 2)
            sparkle.fillColor = SKColor.white
            sparkle.strokeColor = .clear
            sparkle.position = CGPoint(x: CGFloat(drand48()) * 8 - 4, y: driftHeight * 0.3)
            sparkle.alpha = 0.8
            drift.addChild(sparkle)
        }

        return drift
    }

    private func createSwampPool(at position: CGPoint) -> SKNode {
        let pool = SKNode()
        pool.position = position
        pool.zPosition = GameConfig.ZPosition.enemy - 3

        let poolWidth = CGFloat(drand48()) * 25 + 15
        let poolHeight = CGFloat(drand48()) * 15 + 10

        let water = SKShapeNode(ellipseOf: CGSize(width: poolWidth, height: poolHeight))
        water.fillColor = SKColor(red: 0.15, green: 0.22, blue: 0.18, alpha: 0.8)
        water.strokeColor = SKColor(red: 0.2, green: 0.28, blue: 0.22, alpha: 0.5)
        water.lineWidth = 2
        pool.addChild(water)

        // Bubbles
        for _ in 0..<2 {
            let bubble = SKShapeNode(circleOfRadius: CGFloat(drand48()) * 2 + 1)
            bubble.fillColor = SKColor(red: 0.25, green: 0.35, blue: 0.28, alpha: 0.6)
            bubble.strokeColor = .clear
            bubble.position = CGPoint(
                x: CGFloat(drand48()) * poolWidth * 0.5 - poolWidth * 0.25,
                y: CGFloat(drand48()) * poolHeight * 0.3
            )
            pool.addChild(bubble)
        }

        return pool
    }

    private func createDeadTree(at position: CGPoint) -> SKNode {
        let tree = SKNode()
        tree.position = position
        tree.zPosition = GameConfig.ZPosition.enemy - 1

        let trunkHeight: CGFloat = CGFloat(drand48()) * 25 + 30
        let trunkWidth: CGFloat = CGFloat(drand48()) * 6 + 10

        // Dead trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: trunkWidth, height: trunkHeight), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.28, green: 0.24, blue: 0.22, alpha: 1.0)
        trunk.strokeColor = SKColor(red: 0.2, green: 0.17, blue: 0.15, alpha: 1.0)
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: trunkHeight / 2)
        tree.addChild(trunk)

        // Dead branches
        for i in 0..<3 {
            let branchLength = CGFloat(drand48()) * 15 + 8
            let branch = SKShapeNode(rectOf: CGSize(width: 3, height: branchLength))
            branch.fillColor = SKColor(red: 0.3, green: 0.26, blue: 0.24, alpha: 1.0)
            branch.strokeColor = .clear
            let side: CGFloat = (i % 2 == 0) ? 1 : -1
            branch.position = CGPoint(x: side * (trunkWidth / 2 + branchLength / 3),
                                       y: trunkHeight * (0.5 + CGFloat(i) * 0.15))
            branch.zRotation = side * CGFloat(drand48()) * 0.4 + side * 0.8
            tree.addChild(branch)
        }

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 30, height: 12))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.15)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 4, y: -4)
        shadow.zPosition = -1
        tree.addChild(shadow)

        // Physics
        let treeBody = SKPhysicsBody(circleOfRadius: trunkWidth * 1.5)
        treeBody.isDynamic = false
        treeBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        treeBody.collisionBitMask = GameConfig.PhysicsCategory.player
        treeBody.friction = 0
        treeBody.restitution = 0
        tree.physicsBody = treeBody

        return tree
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

    private func createGroundTile(at position: CGPoint, size: CGFloat, biome: Biome) -> SKNode {
        let tile = SKShapeNode(rectOf: CGSize(width: size - 1, height: size - 1))

        // Use biome-specific colors with slight variation
        let variation = CGFloat(drand48()) * biome.groundVariation
        var baseColor = biome.groundColor

        // Apply variation to the base color
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        baseColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        tile.fillColor = SKColor(red: red + variation - biome.groundVariation / 2,
                                  green: green + variation - biome.groundVariation / 2,
                                  blue: blue + variation - biome.groundVariation / 2,
                                  alpha: alpha)
        tile.strokeColor = biome.strokeColor
        tile.lineWidth = 0.5
        tile.position = position

        // Add biome-specific details
        switch biome {
        case .forest:
            // Grass blades
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
            // Dirt patches
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

        case .desert:
            // Sand ripples
            if drand48() < 0.2 {
                let ripple = SKShapeNode(ellipseOf: CGSize(width: size * 0.4, height: 3))
                ripple.fillColor = SKColor(red: 0.7, green: 0.58, blue: 0.4, alpha: 0.4)
                ripple.strokeColor = .clear
                ripple.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.4 - size * 0.2,
                    y: CGFloat(drand48()) * size * 0.4 - size * 0.2
                )
                ripple.zRotation = CGFloat(drand48()) * 0.3
                tile.addChild(ripple)
            }
            // Small pebbles
            if drand48() < 0.15 {
                let pebble = SKShapeNode(circleOfRadius: CGFloat(drand48()) * 3 + 1)
                pebble.fillColor = SKColor(red: 0.55, green: 0.5, blue: 0.4, alpha: 0.6)
                pebble.strokeColor = .clear
                pebble.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.6 - size * 0.3,
                    y: CGFloat(drand48()) * size * 0.6 - size * 0.3
                )
                tile.addChild(pebble)
            }

        case .snow:
            // Snow sparkles
            if drand48() < 0.2 {
                let sparkle = SKShapeNode(circleOfRadius: 1.5)
                sparkle.fillColor = SKColor.white
                sparkle.strokeColor = .clear
                sparkle.alpha = CGFloat(drand48()) * 0.5 + 0.3
                sparkle.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.6 - size * 0.3,
                    y: CGFloat(drand48()) * size * 0.6 - size * 0.3
                )
                tile.addChild(sparkle)
            }
            // Ice patches
            if drand48() < 0.1 {
                let ice = SKShapeNode(ellipseOf: CGSize(width: CGFloat(drand48()) * 10 + 5,
                                                         height: CGFloat(drand48()) * 6 + 3))
                ice.fillColor = SKColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.4)
                ice.strokeColor = .clear
                ice.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.4 - size * 0.2,
                    y: CGFloat(drand48()) * size * 0.4 - size * 0.2
                )
                tile.addChild(ice)
            }

        case .swamp:
            // Murky puddles
            if drand48() < 0.25 {
                let puddle = SKShapeNode(ellipseOf: CGSize(width: CGFloat(drand48()) * 12 + 6,
                                                            height: CGFloat(drand48()) * 8 + 4))
                puddle.fillColor = SKColor(red: 0.12, green: 0.18, blue: 0.12, alpha: 0.5)
                puddle.strokeColor = .clear
                puddle.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.5 - size * 0.25,
                    y: CGFloat(drand48()) * size * 0.5 - size * 0.25
                )
                tile.addChild(puddle)
            }
            // Moss
            if drand48() < 0.2 {
                let moss = SKShapeNode(circleOfRadius: CGFloat(drand48()) * 5 + 2)
                moss.fillColor = SKColor(red: 0.25, green: 0.35, blue: 0.2, alpha: 0.5)
                moss.strokeColor = .clear
                moss.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.6 - size * 0.3,
                    y: CGFloat(drand48()) * size * 0.6 - size * 0.3
                )
                tile.addChild(moss)
            }

        case .ruins:
            // Cracked stone
            if drand48() < 0.2 {
                let crack = SKShapeNode(rectOf: CGSize(width: 1, height: CGFloat(drand48()) * 10 + 5))
                crack.fillColor = SKColor(red: 0.15, green: 0.12, blue: 0.18, alpha: 0.4)
                crack.strokeColor = .clear
                crack.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.5 - size * 0.25,
                    y: CGFloat(drand48()) * size * 0.5 - size * 0.25
                )
                crack.zRotation = CGFloat(drand48()) * .pi
                tile.addChild(crack)
            }
            // Bone fragments
            if drand48() < 0.08 {
                let bone = SKShapeNode(ellipseOf: CGSize(width: 4, height: 2))
                bone.fillColor = SKColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 0.6)
                bone.strokeColor = .clear
                bone.position = CGPoint(
                    x: CGFloat(drand48()) * size * 0.6 - size * 0.3,
                    y: CGFloat(drand48()) * size * 0.6 - size * 0.3
                )
                bone.zRotation = CGFloat(drand48()) * .pi
                tile.addChild(bone)
            }
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

    // MARK: - Biome System

    private enum Biome {
        case forest      // Default green forest
        case desert      // Sandy wasteland
        case snow        // Frozen tundra
        case swamp       // Dark murky swamp
        case ruins       // Ancient ruins/graveyard

        var groundColor: SKColor {
            switch self {
            case .forest: return SKColor(red: 0.18, green: 0.28, blue: 0.12, alpha: 1.0)
            case .desert: return SKColor(red: 0.76, green: 0.65, blue: 0.45, alpha: 1.0)
            case .snow: return SKColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1.0)
            case .swamp: return SKColor(red: 0.2, green: 0.25, blue: 0.18, alpha: 1.0)
            case .ruins: return SKColor(red: 0.25, green: 0.22, blue: 0.28, alpha: 1.0)
            }
        }

        var groundVariation: CGFloat {
            switch self {
            case .forest: return 0.08
            case .desert: return 0.05
            case .snow: return 0.03
            case .swamp: return 0.06
            case .ruins: return 0.04
            }
        }

        var strokeColor: SKColor {
            switch self {
            case .forest: return SKColor(red: 0.12, green: 0.2, blue: 0.08, alpha: 0.3)
            case .desert: return SKColor(red: 0.6, green: 0.5, blue: 0.35, alpha: 0.3)
            case .snow: return SKColor(red: 0.7, green: 0.75, blue: 0.8, alpha: 0.3)
            case .swamp: return SKColor(red: 0.15, green: 0.18, blue: 0.12, alpha: 0.4)
            case .ruins: return SKColor(red: 0.18, green: 0.15, blue: 0.2, alpha: 0.3)
            }
        }
    }

    private func getBiome(at position: CGPoint) -> Biome {
        // Use noise-like function based on world coordinates
        // Each biome zone is roughly 800-1200 units wide
        let biomeScale: CGFloat = 800.0

        // Use sin/cos to create smooth biome transitions
        let nx = sin(position.x / biomeScale * 0.7) + cos(position.y / biomeScale * 0.5)
        let ny = cos(position.x / biomeScale * 0.5) - sin(position.y / biomeScale * 0.8)

        // Combine for biome selection
        let biomeValue = (nx + ny) / 2.0

        // Forest around spawn (within ~400 units)
        let distFromOrigin = sqrt(position.x * position.x + position.y * position.y)
        if distFromOrigin < 400 {
            return .forest
        }

        // Select biome based on value
        if biomeValue < -0.6 {
            return .snow
        } else if biomeValue < -0.2 {
            return .ruins
        } else if biomeValue < 0.3 {
            return .forest
        } else if biomeValue < 0.7 {
            return .swamp
        } else {
            return .desert
        }
    }

    // MARK: - Biome-Specific Structures

    private func createHouse(at position: CGPoint, biome: Biome) -> SKNode {
        let house = SKNode()
        house.position = position
        house.zPosition = GameConfig.ZPosition.enemy - 1

        let houseWidth: CGFloat = CGFloat(drand48()) * 30 + 50
        let houseHeight: CGFloat = CGFloat(drand48()) * 20 + 35
        let roofHeight: CGFloat = houseHeight * 0.5

        // Wall color based on biome
        let wallColor: SKColor
        let roofColor: SKColor
        switch biome {
        case .forest:
            wallColor = SKColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1.0)
            roofColor = SKColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1.0)
        case .desert:
            wallColor = SKColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1.0)
            roofColor = SKColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)
        case .snow:
            wallColor = SKColor(red: 0.7, green: 0.72, blue: 0.75, alpha: 1.0)
            roofColor = SKColor(red: 0.3, green: 0.35, blue: 0.4, alpha: 1.0)
        case .swamp:
            wallColor = SKColor(red: 0.35, green: 0.38, blue: 0.32, alpha: 1.0)
            roofColor = SKColor(red: 0.25, green: 0.3, blue: 0.22, alpha: 1.0)
        case .ruins:
            wallColor = SKColor(red: 0.4, green: 0.38, blue: 0.42, alpha: 1.0)
            roofColor = SKColor(red: 0.3, green: 0.28, blue: 0.32, alpha: 1.0)
        }

        // House base/walls
        let walls = SKShapeNode(rectOf: CGSize(width: houseWidth, height: houseHeight), cornerRadius: 2)
        walls.fillColor = wallColor
        walls.strokeColor = wallColor.blended(with: .black, amount: 0.3)
        walls.lineWidth = 2
        walls.position = CGPoint(x: 0, y: houseHeight / 2)
        house.addChild(walls)

        // Roof (triangle)
        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: -houseWidth / 2 - 5, y: houseHeight))
        roofPath.addLine(to: CGPoint(x: 0, y: houseHeight + roofHeight))
        roofPath.addLine(to: CGPoint(x: houseWidth / 2 + 5, y: houseHeight))
        roofPath.closeSubpath()

        let roof = SKShapeNode(path: roofPath)
        roof.fillColor = roofColor
        roof.strokeColor = roofColor.blended(with: .black, amount: 0.2)
        roof.lineWidth = 2
        house.addChild(roof)

        // Door
        let doorWidth: CGFloat = houseWidth * 0.25
        let doorHeight: CGFloat = houseHeight * 0.5
        let door = SKShapeNode(rectOf: CGSize(width: doorWidth, height: doorHeight))
        door.fillColor = SKColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 1.0)
        door.strokeColor = SKColor(red: 0.15, green: 0.1, blue: 0.05, alpha: 1.0)
        door.lineWidth = 1
        door.position = CGPoint(x: 0, y: doorHeight / 2)
        house.addChild(door)

        // Window
        let windowSize: CGFloat = houseHeight * 0.2
        let window = SKShapeNode(rectOf: CGSize(width: windowSize, height: windowSize))
        window.fillColor = SKColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 0.7)
        window.strokeColor = SKColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)
        window.lineWidth = 1
        window.position = CGPoint(x: houseWidth * 0.3, y: houseHeight * 0.6)
        house.addChild(window)

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: houseWidth * 1.3, height: houseHeight * 0.4))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 8, y: -5)
        shadow.zPosition = -1
        house.addChild(shadow)

        // Physics body for collision
        let houseBody = SKPhysicsBody(rectangleOf: CGSize(width: houseWidth, height: houseHeight),
                                       center: CGPoint(x: 0, y: houseHeight / 2))
        houseBody.isDynamic = false
        houseBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        houseBody.collisionBitMask = GameConfig.PhysicsCategory.player
        houseBody.friction = 0
        houseBody.restitution = 0
        house.physicsBody = houseBody

        return house
    }

    private func createGravestone(at position: CGPoint) -> SKNode {
        let grave = SKNode()
        grave.position = position
        grave.zPosition = GameConfig.ZPosition.enemy - 2

        let width: CGFloat = CGFloat(drand48()) * 8 + 12
        let height: CGFloat = CGFloat(drand48()) * 15 + 20

        // Gravestone shape
        let stonePath = CGMutablePath()
        stonePath.move(to: CGPoint(x: -width / 2, y: 0))
        stonePath.addLine(to: CGPoint(x: -width / 2, y: height * 0.7))
        stonePath.addQuadCurve(to: CGPoint(x: width / 2, y: height * 0.7),
                                control: CGPoint(x: 0, y: height + 5))
        stonePath.addLine(to: CGPoint(x: width / 2, y: 0))
        stonePath.closeSubpath()

        let stone = SKShapeNode(path: stonePath)
        stone.fillColor = SKColor(red: 0.45, green: 0.43, blue: 0.48, alpha: 1.0)
        stone.strokeColor = SKColor(red: 0.3, green: 0.28, blue: 0.32, alpha: 1.0)
        stone.lineWidth = 1
        grave.addChild(stone)

        // Cross or marking on gravestone
        if drand48() < 0.6 {
            let crossV = SKShapeNode(rectOf: CGSize(width: 2, height: height * 0.4))
            crossV.fillColor = SKColor(red: 0.35, green: 0.33, blue: 0.38, alpha: 1.0)
            crossV.strokeColor = .clear
            crossV.position = CGPoint(x: 0, y: height * 0.45)
            grave.addChild(crossV)

            let crossH = SKShapeNode(rectOf: CGSize(width: width * 0.5, height: 2))
            crossH.fillColor = SKColor(red: 0.35, green: 0.33, blue: 0.38, alpha: 1.0)
            crossH.strokeColor = .clear
            crossH.position = CGPoint(x: 0, y: height * 0.55)
            grave.addChild(crossH)
        }

        // Small dirt mound
        let mound = SKShapeNode(ellipseOf: CGSize(width: width * 2, height: 8))
        mound.fillColor = SKColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 0.6)
        mound.strokeColor = .clear
        mound.position = CGPoint(x: 0, y: -2)
        mound.zPosition = -1
        grave.addChild(mound)

        // Physics - small collision
        let graveBody = SKPhysicsBody(circleOfRadius: width * 0.8)
        graveBody.isDynamic = false
        graveBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        graveBody.collisionBitMask = GameConfig.PhysicsCategory.player
        graveBody.friction = 0
        graveBody.restitution = 0
        grave.physicsBody = graveBody

        return grave
    }

    private func createFence(at position: CGPoint, biome: Biome) -> SKNode {
        let fence = SKNode()
        fence.position = position
        fence.zPosition = GameConfig.ZPosition.enemy - 2

        let postCount = Int(drand48() * 2) + 3  // 3-4 posts
        let postSpacing: CGFloat = 18
        let totalWidth = CGFloat(postCount - 1) * postSpacing

        let fenceColor: SKColor
        switch biome {
        case .snow:
            fenceColor = SKColor(red: 0.6, green: 0.62, blue: 0.65, alpha: 1.0)
        case .swamp:
            fenceColor = SKColor(red: 0.3, green: 0.32, blue: 0.28, alpha: 1.0)
        default:
            fenceColor = SKColor(red: 0.4, green: 0.32, blue: 0.22, alpha: 1.0)
        }

        // Horizontal rail
        let rail = SKShapeNode(rectOf: CGSize(width: totalWidth + 10, height: 4))
        rail.fillColor = fenceColor
        rail.strokeColor = fenceColor.blended(with: .black, amount: 0.2)
        rail.lineWidth = 1
        rail.position = CGPoint(x: 0, y: 15)
        fence.addChild(rail)

        // Posts
        for i in 0..<postCount {
            let x = CGFloat(i) * postSpacing - totalWidth / 2
            let postHeight: CGFloat = CGFloat(drand48()) * 8 + 22

            let post = SKShapeNode(rectOf: CGSize(width: 5, height: postHeight))
            post.fillColor = fenceColor
            post.strokeColor = fenceColor.blended(with: .black, amount: 0.2)
            post.lineWidth = 1
            post.position = CGPoint(x: x, y: postHeight / 2)
            fence.addChild(post)

            // Pointed top
            let topPath = CGMutablePath()
            topPath.move(to: CGPoint(x: x - 3, y: postHeight))
            topPath.addLine(to: CGPoint(x: x, y: postHeight + 5))
            topPath.addLine(to: CGPoint(x: x + 3, y: postHeight))
            topPath.closeSubpath()
            let top = SKShapeNode(path: topPath)
            top.fillColor = fenceColor
            top.strokeColor = .clear
            fence.addChild(top)
        }

        // Physics body
        let fenceBody = SKPhysicsBody(rectangleOf: CGSize(width: totalWidth + 10, height: 25),
                                       center: CGPoint(x: 0, y: 12))
        fenceBody.isDynamic = false
        fenceBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        fenceBody.collisionBitMask = GameConfig.PhysicsCategory.player
        fenceBody.friction = 0
        fenceBody.restitution = 0
        fence.physicsBody = fenceBody

        return fence
    }

    private func createWell(at position: CGPoint) -> SKNode {
        let well = SKNode()
        well.position = position
        well.zPosition = GameConfig.ZPosition.enemy - 1

        let radius: CGFloat = 20

        // Stone base (circular)
        let base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = SKColor(red: 0.45, green: 0.42, blue: 0.4, alpha: 1.0)
        base.strokeColor = SKColor(red: 0.35, green: 0.32, blue: 0.3, alpha: 1.0)
        base.lineWidth = 3
        well.addChild(base)

        // Inner dark water
        let water = SKShapeNode(circleOfRadius: radius * 0.6)
        water.fillColor = SKColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0)
        water.strokeColor = .clear
        well.addChild(water)

        // Roof posts
        let postHeight: CGFloat = 35
        for xMult: CGFloat in [-1, 1] {
            let post = SKShapeNode(rectOf: CGSize(width: 4, height: postHeight))
            post.fillColor = SKColor(red: 0.35, green: 0.28, blue: 0.2, alpha: 1.0)
            post.strokeColor = SKColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 1.0)
            post.lineWidth = 1
            post.position = CGPoint(x: xMult * (radius - 3), y: postHeight / 2)
            well.addChild(post)
        }

        // Roof
        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: -radius - 5, y: postHeight))
        roofPath.addLine(to: CGPoint(x: 0, y: postHeight + 15))
        roofPath.addLine(to: CGPoint(x: radius + 5, y: postHeight))
        roofPath.closeSubpath()
        let roof = SKShapeNode(path: roofPath)
        roof.fillColor = SKColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1.0)
        roof.strokeColor = SKColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        roof.lineWidth = 2
        well.addChild(roof)

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: radius * 2.5, height: radius))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 5, y: -5)
        shadow.zPosition = -1
        well.addChild(shadow)

        // Physics body
        let wellBody = SKPhysicsBody(circleOfRadius: radius)
        wellBody.isDynamic = false
        wellBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        wellBody.collisionBitMask = GameConfig.PhysicsCategory.player
        wellBody.friction = 0
        wellBody.restitution = 0
        well.physicsBody = wellBody

        return well
    }

    private func createCactus(at position: CGPoint) -> SKNode {
        let cactus = SKNode()
        cactus.position = position
        cactus.zPosition = GameConfig.ZPosition.enemy - 2

        let cactusColor = SKColor(red: 0.3, green: 0.55, blue: 0.3, alpha: 1.0)
        let height: CGFloat = CGFloat(drand48()) * 25 + 30

        // Main body
        let body = SKShapeNode(rectOf: CGSize(width: 14, height: height), cornerRadius: 6)
        body.fillColor = cactusColor
        body.strokeColor = SKColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 1.0)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: height / 2)
        cactus.addChild(body)

        // Arms
        if drand48() < 0.7 {
            let armHeight: CGFloat = height * 0.3
            let armY = height * (0.4 + CGFloat(drand48()) * 0.3)
            let armSide: CGFloat = drand48() < 0.5 ? -1 : 1

            // Horizontal part
            let armH = SKShapeNode(rectOf: CGSize(width: 15, height: 10), cornerRadius: 4)
            armH.fillColor = cactusColor
            armH.strokeColor = SKColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 1.0)
            armH.lineWidth = 1
            armH.position = CGPoint(x: armSide * 14, y: armY)
            cactus.addChild(armH)

            // Vertical part
            let armV = SKShapeNode(rectOf: CGSize(width: 10, height: armHeight), cornerRadius: 4)
            armV.fillColor = cactusColor
            armV.strokeColor = SKColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 1.0)
            armV.lineWidth = 1
            armV.position = CGPoint(x: armSide * 19, y: armY + armHeight / 2)
            cactus.addChild(armV)
        }

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 25, height: 10))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.15)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = -1
        cactus.addChild(shadow)

        // Physics
        let cactusBody = SKPhysicsBody(circleOfRadius: 10)
        cactusBody.isDynamic = false
        cactusBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        cactusBody.collisionBitMask = GameConfig.PhysicsCategory.player
        cactusBody.friction = 0
        cactusBody.restitution = 0
        cactus.physicsBody = cactusBody

        return cactus
    }

    private func createSnowTree(at position: CGPoint) -> SKNode {
        let tree = SKNode()
        tree.position = position
        tree.zPosition = GameConfig.ZPosition.enemy - 1

        let trunkHeight: CGFloat = CGFloat(drand48()) * 15 + 25
        let trunkWidth: CGFloat = CGFloat(drand48()) * 6 + 10

        // Trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: trunkWidth, height: trunkHeight), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
        trunk.strokeColor = SKColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: trunkHeight / 2)
        tree.addChild(trunk)

        // Snow-covered pine foliage (triangles stacked)
        let pineColor = SKColor(red: 0.2, green: 0.35, blue: 0.25, alpha: 1.0)
        let snowColor = SKColor(red: 0.9, green: 0.92, blue: 0.95, alpha: 0.8)

        for i in 0..<3 {
            let layerY = trunkHeight + CGFloat(i) * 18
            let layerSize: CGFloat = 30 - CGFloat(i) * 8

            let pinePath = CGMutablePath()
            pinePath.move(to: CGPoint(x: -layerSize, y: layerY))
            pinePath.addLine(to: CGPoint(x: 0, y: layerY + 25))
            pinePath.addLine(to: CGPoint(x: layerSize, y: layerY))
            pinePath.closeSubpath()

            let pine = SKShapeNode(path: pinePath)
            pine.fillColor = pineColor
            pine.strokeColor = SKColor(red: 0.15, green: 0.25, blue: 0.18, alpha: 1.0)
            pine.lineWidth = 1
            tree.addChild(pine)

            // Snow on top
            let snowPath = CGMutablePath()
            snowPath.move(to: CGPoint(x: -layerSize * 0.7, y: layerY + 15))
            snowPath.addLine(to: CGPoint(x: 0, y: layerY + 25))
            snowPath.addLine(to: CGPoint(x: layerSize * 0.7, y: layerY + 15))
            snowPath.closeSubpath()

            let snow = SKShapeNode(path: snowPath)
            snow.fillColor = snowColor
            snow.strokeColor = .clear
            tree.addChild(snow)
        }

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 15))
        shadow.fillColor = SKColor(red: 0.5, green: 0.55, blue: 0.6, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 5, y: -5)
        shadow.zPosition = -1
        tree.addChild(shadow)

        // Physics
        let treeBody = SKPhysicsBody(circleOfRadius: trunkWidth * 1.5)
        treeBody.isDynamic = false
        treeBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        treeBody.collisionBitMask = GameConfig.PhysicsCategory.player
        treeBody.friction = 0
        treeBody.restitution = 0
        tree.physicsBody = treeBody

        return tree
    }

    private func createSwampTree(at position: CGPoint) -> SKNode {
        let tree = SKNode()
        tree.position = position
        tree.zPosition = GameConfig.ZPosition.enemy - 1

        let trunkHeight: CGFloat = CGFloat(drand48()) * 20 + 35
        let trunkWidth: CGFloat = CGFloat(drand48()) * 6 + 10

        // Gnarled trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: trunkWidth, height: trunkHeight), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1.0)
        trunk.strokeColor = SKColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1.0)
        trunk.lineWidth = 2
        trunk.position = CGPoint(x: 0, y: trunkHeight / 2)
        tree.addChild(trunk)

        // Sparse, droopy foliage
        let foliageColor = SKColor(red: 0.25, green: 0.35, blue: 0.22, alpha: 0.8)

        for i in 0..<4 {
            let foliage = SKShapeNode(ellipseOf: CGSize(width: 20 - CGFloat(i) * 3, height: 12))
            foliage.fillColor = foliageColor
            foliage.strokeColor = SKColor(red: 0.18, green: 0.28, blue: 0.15, alpha: 0.5)
            foliage.lineWidth = 1
            foliage.position = CGPoint(
                x: CGFloat(drand48()) * 20 - 10,
                y: trunkHeight + CGFloat(drand48()) * 15
            )
            tree.addChild(foliage)
        }

        // Hanging moss/vines
        for _ in 0..<3 {
            let vineLength = CGFloat(drand48()) * 20 + 10
            let vine = SKShapeNode(rectOf: CGSize(width: 2, height: vineLength))
            vine.fillColor = SKColor(red: 0.3, green: 0.38, blue: 0.28, alpha: 0.7)
            vine.strokeColor = .clear
            vine.position = CGPoint(
                x: CGFloat(drand48()) * 30 - 15,
                y: trunkHeight - vineLength / 2
            )
            tree.addChild(vine)
        }

        // Murky water puddle
        let puddle = SKShapeNode(ellipseOf: CGSize(width: 30, height: 12))
        puddle.fillColor = SKColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 0.5)
        puddle.strokeColor = .clear
        puddle.position = CGPoint(x: 5, y: -5)
        puddle.zPosition = -1
        tree.addChild(puddle)

        // Physics
        let treeBody = SKPhysicsBody(circleOfRadius: trunkWidth * 1.5)
        treeBody.isDynamic = false
        treeBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        treeBody.collisionBitMask = GameConfig.PhysicsCategory.player
        treeBody.friction = 0
        treeBody.restitution = 0
        tree.physicsBody = treeBody

        return tree
    }

    private func createRuinPillar(at position: CGPoint) -> SKNode {
        let pillar = SKNode()
        pillar.position = position
        pillar.zPosition = GameConfig.ZPosition.enemy - 2

        let pillarHeight: CGFloat = CGFloat(drand48()) * 30 + 25
        let pillarWidth: CGFloat = CGFloat(drand48()) * 8 + 12

        // Broken pillar
        let pillarPath = CGMutablePath()
        pillarPath.move(to: CGPoint(x: -pillarWidth / 2, y: 0))
        pillarPath.addLine(to: CGPoint(x: -pillarWidth / 2 + 2, y: pillarHeight * 0.8))
        pillarPath.addLine(to: CGPoint(x: -pillarWidth / 4, y: pillarHeight))
        pillarPath.addLine(to: CGPoint(x: pillarWidth / 4, y: pillarHeight * 0.85))
        pillarPath.addLine(to: CGPoint(x: pillarWidth / 2 - 2, y: pillarHeight * 0.9))
        pillarPath.addLine(to: CGPoint(x: pillarWidth / 2, y: 0))
        pillarPath.closeSubpath()

        let stone = SKShapeNode(path: pillarPath)
        stone.fillColor = SKColor(red: 0.5, green: 0.48, blue: 0.52, alpha: 1.0)
        stone.strokeColor = SKColor(red: 0.35, green: 0.33, blue: 0.38, alpha: 1.0)
        stone.lineWidth = 2
        pillar.addChild(stone)

        // Cracks
        let crack = SKShapeNode(rectOf: CGSize(width: 1, height: pillarHeight * 0.4))
        crack.fillColor = SKColor(red: 0.3, green: 0.28, blue: 0.32, alpha: 0.6)
        crack.strokeColor = .clear
        crack.position = CGPoint(x: CGFloat(drand48()) * pillarWidth * 0.5 - pillarWidth * 0.25, y: pillarHeight * 0.3)
        crack.zRotation = CGFloat(drand48()) * 0.3 - 0.15
        pillar.addChild(crack)

        // Rubble around base
        for _ in 0..<3 {
            let rubbleSize = CGFloat(drand48()) * 5 + 3
            let rubble = SKShapeNode(circleOfRadius: rubbleSize)
            rubble.fillColor = SKColor(red: 0.45, green: 0.43, blue: 0.47, alpha: 0.8)
            rubble.strokeColor = .clear
            rubble.position = CGPoint(
                x: CGFloat(drand48()) * pillarWidth * 1.5 - pillarWidth * 0.75,
                y: CGFloat(drand48()) * 5 - 5
            )
            rubble.zPosition = -1
            pillar.addChild(rubble)
        }

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: pillarWidth * 2, height: pillarWidth * 0.8))
        shadow.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.15)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = -2
        pillar.addChild(shadow)

        // Physics
        let pillarBody = SKPhysicsBody(circleOfRadius: pillarWidth)
        pillarBody.isDynamic = false
        pillarBody.categoryBitMask = GameConfig.PhysicsCategory.boundary
        pillarBody.collisionBitMask = GameConfig.PhysicsCategory.player
        pillarBody.friction = 0
        pillarBody.restitution = 0
        pillar.physicsBody = pillarBody

        return pillar
    }

    private func setupPlayer() {
        player = Player(characterClass: selectedCharacterClass)
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

        // Remove wave notification if visible to prevent overlap with pause text
        gameCamera.childNode(withName: "waveNotification")?.removeFromParent()

        uiManager.showPauseScreen()
    }

    private func resumeGame() {
        guard gameState == .paused else { return }

        gameState = .playing
        isPaused = false
        hitFreezeActive = false
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

        // Remove all danger zones
        for zone in dangerZones {
            zone.removeFromParent()
        }
        dangerZones.removeAll()
        lastDangerZoneTime = 0
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
        updateDangerZones(deltaTime: deltaTime)

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
        // Advanced abilities
        if player.abilities.hasTimeSlow {
            uiManager.updateAbilityCooldown(.timeSlow,
                remaining: player.abilities.timeSlowCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.timeSlow)
        }
        if player.abilities.hasTeleport {
            uiManager.updateAbilityCooldown(.teleport,
                remaining: player.abilities.teleportCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.teleport)
        }
        if player.abilities.hasReflect {
            uiManager.updateAbilityCooldown(.reflect,
                remaining: player.abilities.reflectCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.reflect)
        }
        if player.abilities.hasVortex {
            uiManager.updateAbilityCooldown(.vortex,
                remaining: player.abilities.vortexCooldownRemaining,
                total: UpgradeConfig.AbilityCooldowns.vortex)
        }
    }

    private func updateEnemies(deltaTime: TimeInterval) {
        // Apply time slow effect if active
        let effectiveDeltaTime = player.abilities.isTimeSlowActive ? deltaTime * 0.3 : deltaTime

        for enemy in enemies {
            enemy.update(deltaTime: effectiveDeltaTime)
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

        // Create bounds around player for projectile cleanup (not scene origin)
        let projectileBounds = CGRect(
            x: player.position.x - size.width,
            y: player.position.y - size.height,
            width: size.width * 2,
            height: size.height * 2
        )

        for projectile in projectiles {
            projectile.update(deltaTime: deltaTime, enemies: projectile.isPlayerProjectile ? enemies : nil)

            // Check bounds relative to player, not scene origin
            if !projectile.isActive || projectile.isOutOfBounds(bounds: projectileBounds) {
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

    // MARK: - Wave 10+ Danger Zones

    private func updateDangerZones(deltaTime: TimeInterval) {
        guard waveManager.currentWave >= WaveConfig.dangerZoneWave else { return }

        lastDangerZoneTime += deltaTime

        // Spawn new danger zone periodically
        if lastDangerZoneTime >= WaveConfig.dangerZoneInterval {
            lastDangerZoneTime = 0
            spawnDangerZone()
        }

        // Clean up expired zones
        dangerZones.removeAll { $0.parent == nil }
    }

    private func spawnDangerZone() {
        // Spawn danger zone near player (but not directly on them)
        let angle = CGFloat.random(in: 0...(.pi * 2))
        let distance = CGFloat.random(in: 50...150)
        let spawnPos = CGPoint(
            x: player.position.x + cos(angle) * distance,
            y: player.position.y + sin(angle) * distance
        )

        let dangerZone = createDangerZone(at: spawnPos)
        gameLayer.addChild(dangerZone)
        dangerZones.append(dangerZone)
    }

    private func createDangerZone(at position: CGPoint) -> SKNode {
        let zone = SKNode()
        zone.position = position
        zone.zPosition = GameConfig.ZPosition.floor + 1

        let radius = WaveConfig.dangerZoneRadius

        // Warning indicator (red circle that grows)
        let warningCircle = SKShapeNode(circleOfRadius: radius)
        warningCircle.fillColor = SKColor.red.withAlphaComponent(0.2)
        warningCircle.strokeColor = SKColor.red
        warningCircle.lineWidth = 3
        warningCircle.glowWidth = 5
        warningCircle.setScale(0.3)
        zone.addChild(warningCircle)

        // Inner danger indicator
        let innerCircle = SKShapeNode(circleOfRadius: radius * 0.5)
        innerCircle.fillColor = .clear
        innerCircle.strokeColor = SKColor.red.withAlphaComponent(0.8)
        innerCircle.lineWidth = 2
        warningCircle.addChild(innerCircle)

        // Pulse animation during warning phase
        let pulseAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.5),
                SKAction.run { warningCircle.fillColor = SKColor.red.withAlphaComponent(0.3) }
            ]),
            SKAction.group([
                SKAction.scale(to: 0.9, duration: 0.3),
                SKAction.run { warningCircle.fillColor = SKColor.red.withAlphaComponent(0.2) }
            ])
        ])

        // Warning phase then explosion
        let warningDuration = WaveConfig.dangerZoneDuration - 0.5

        let sequence = SKAction.sequence([
            SKAction.repeat(pulseAction, count: Int(warningDuration / 0.8)),
            SKAction.run { [weak self, weak zone] in
                guard let self = self, let zone = zone else { return }
                self.explodeDangerZone(zone, radius: radius)
            },
            SKAction.wait(forDuration: 0.3),
            SKAction.removeFromParent()
        ])

        zone.run(sequence)

        return zone
    }

    private func explodeDangerZone(_ zone: SKNode, radius: CGFloat) {
        // Visual explosion
        let explosion = SKShapeNode(circleOfRadius: radius)
        explosion.fillColor = SKColor.red.withAlphaComponent(0.8)
        explosion.strokeColor = SKColor.orange
        explosion.lineWidth = 4
        explosion.glowWidth = 10
        explosion.setScale(0.5)
        zone.addChild(explosion)

        // Explosion animation
        let expandAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.2, duration: 0.15),
                SKAction.fadeAlpha(to: 0.6, duration: 0.15)
            ]),
            SKAction.group([
                SKAction.scale(to: 0.8, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.2)
            ])
        ])
        explosion.run(expandAction)

        // Check if player is in range and deal damage
        let dx = player.position.x - zone.position.x
        let dy = player.position.y - zone.position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance <= radius {
            player.takeDamage(WaveConfig.dangerZoneDamage)
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle ALL touches for multi-touch support (joystick + abilities)
        for touch in touches {
            let location = touch.location(in: self)

            // Check UI/ability buttons first (works even while moving)
            if uiManager.handleTouch(at: location) {
                continue
            }

            // Right side screen tap for quick abilities (if not hitting a specific button)
            let cameraLocation = CGPoint(
                x: location.x - (camera?.position.x ?? 0),
                y: location.y - (camera?.position.y ?? 0)
            )
            if cameraLocation.x > 0 {  // Right half of camera view
                // Don't auto-trigger abilities - let the buttons handle it
                // This prevents accidental ability use
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

        // CRITICAL: Ensure scene is not paused when resuming gameplay
        // This can happen if triggerHitFreeze was active when transitioning to upgrade screen
        isPaused = false
        hitFreezeActive = false

        // Force cleanup of any dead enemies still in array
        enemies.removeAll { $0.isDead }

        // Remove any lingering enemy nodes that might have been orphaned
        for child in gameLayer.children {
            if let enemy = child as? Enemy, enemy.isDead {
                enemy.removeFromParent()
            }
        }

        // Clean up inactive projectiles
        projectiles.removeAll { !$0.isActive }
        for projectile in projectiles where !projectile.isActive {
            projectile.removeFromParent()
        }

        // Clean up danger zones
        for zone in dangerZones {
            zone.removeFromParent()
        }
        dangerZones.removeAll()

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
        let damageDealt = projectile.damage
        enemy.takeDamage(damageDealt, isCritical: projectile.isCritical)
        GameManager.shared.recordDamageDealt(Int(damageDealt))
        totalDamageDealt += Int(damageDealt)

        if projectile.isCritical {
            GameManager.shared.recordCriticalHit()
            // Screen shake for crits (reduced intensity)
            triggerScreenShake(intensity: 2, duration: 0.08)
            AudioManager.shared.playSFX(.critHit, on: self)
        } else {
            AudioManager.shared.playSFX(.enemyHit, on: self)
        }

        // Check overkill achievement
        AchievementManager.shared.checkOverkill(damageDealt: damageDealt, enemyHealth: enemy.maxHealth)

        // Apply life steal and update UI
        let healthBefore = player.stats.currentHealth
        player.applyLifeSteal(from: damageDealt)
        if player.stats.currentHealth > healthBefore {
            uiManager.updateHealth(current: player.stats.currentHealth, max: player.stats.maxHealth)
            // Show heal visual
            showHealEffect(amount: player.stats.currentHealth - healthBefore)
        }

        // Handle projectile
        projectile.onHit()
    }

    private func showHealEffect(amount: CGFloat) {
        // Throttle heal effects to prevent node/action accumulation during rapid attacks
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastHealEffectTime >= healEffectThrottle else { return }
        lastHealEffectTime = currentTime

        let healLabel = SKLabelNode(fontNamed: UIConfig.fontName)
        healLabel.text = "+\(Int(amount))"
        healLabel.fontSize = 14
        healLabel.fontColor = SKColor.green
        healLabel.position = CGPoint(x: player.position.x, y: player.position.y + 40)
        healLabel.zPosition = GameConfig.ZPosition.effects
        gameLayer.addChild(healLabel)

        let floatUp = SKAction.moveBy(x: 0, y: 30, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        healLabel.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut]),
            SKAction.removeFromParent()
        ]))

        // Haptic for heal
        AudioManager.shared.playSFX(.heal, on: self)
    }

    // MARK: - Enhanced Screen Shake

    private func triggerScreenShake(intensity: CGFloat, duration: TimeInterval = 0.2) {
        // Check if screen shake is enabled
        guard GameManager.shared.screenShakeEnabled else { return }

        // Cancel any existing shake and reset position
        if isShaking {
            gameCamera.removeAction(forKey: "screenShake")
            gameCamera.position = cameraOriginalPosition
        }

        isShaking = true
        cameraOriginalPosition = gameCamera.position

        let shakeCount = Int(duration / 0.02)
        var shakeActions: [SKAction] = []

        for i in 0..<shakeCount {
            let decreasing = 1.0 - (CGFloat(i) / CGFloat(shakeCount))
            let dx = CGFloat.random(in: -intensity...intensity) * decreasing
            let dy = CGFloat.random(in: -intensity...intensity) * decreasing
            shakeActions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.02))
        }

        // Return to original position
        shakeActions.append(SKAction.move(to: cameraOriginalPosition, duration: 0.05))
        shakeActions.append(SKAction.run { [weak self] in
            self?.isShaking = false
        })

        gameCamera.run(SKAction.sequence(shakeActions), withKey: "screenShake")
    }

    private func triggerHitFreeze(duration: TimeInterval = 0.03) {
        // Prevent stacking freezes
        guard !hitFreezeActive else { return }
        hitFreezeActive = true

        // Brief pause for impactful hits
        // IMPORTANT: Use DispatchQueue instead of SKAction because isPaused
        // also pauses actions, which would prevent the unpause from running!
        isPaused = true

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            self.hitFreezeActive = false
            guard self.gameState == .playing else { return }
            self.isPaused = false
        }
    }

    private func handleEnemyProjectilePlayerCollision(_ contact: SKPhysicsContact) {
        let projectileNode = contact.bodyA.categoryBitMask == GameConfig.PhysicsCategory.enemyProjectile ?
            contact.bodyA.node : contact.bodyB.node

        guard let projectile = projectileNode as? Projectile,
              projectile.isActive else { return }

        // If reflect is active, reflect the projectile back!
        if player.abilities.isReflectActive {
            reflectProjectile(projectile)
            return
        }

        player.takeDamage(projectile.damage)
        projectile.deactivate()
    }

    private func reflectProjectile(_ projectile: Projectile) {
        // Reverse projectile direction and make it a player projectile
        projectile.reflect()

        // Change physics category to player projectile
        projectile.physicsBody?.categoryBitMask = GameConfig.PhysicsCategory.playerProjectile
        projectile.physicsBody?.contactTestBitMask = GameConfig.PhysicsCategory.enemy

        // Visual feedback - golden flash
        let flashAction = SKAction.sequence([
            SKAction.colorize(with: .yellow, colorBlendFactor: 1.0, duration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.2)
        ])
        projectile.run(flashAction)

        // Move from enemy projectiles to player projectiles array
        // (Already in projectiles array, just changed category)
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
        damageTakenThisWave += amount

        // Screen shake based on damage (reduced intensity)
        let intensity = min(amount / 15, 4)
        triggerScreenShake(intensity: intensity, duration: 0.1)

        // Hit freeze for big hits only
        if amount >= 30 {
            triggerHitFreeze(duration: 0.03)
        }

        // Check close call achievement
        AchievementManager.shared.checkCloseCall(currentHealth: player.stats.currentHealth)

        // Haptic feedback
        AudioManager.shared.playSFX(.playerHit, on: self)
    }

    func playerDidDie() {
        gameOver()
    }

    func playerDidLevelUp(newLevel: Int) {
        uiManager.updateXP(current: player.stats.currentXP, max: player.stats.xpToNextLevel, level: newLevel)

        // Level up effect - add to camera so it stays on screen
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = SKColor.white.withAlphaComponent(0.3)
        flash.strokeColor = .clear
        flash.position = .zero  // Center of camera
        flash.zPosition = GameConfig.ZPosition.overlay - 1
        gameCamera.addChild(flash)

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
        waveStartTime = gameTime
        damageTakenThisWave = 0

        // Show wave start notification
        showWaveNotification(wave: wave, modifiers: data.modifiers, isBoss: data.isBossWave)

        // Audio
        AudioManager.shared.playSFX(.waveStart, on: self)
    }

    func waveDidEnd(wave: Int, data: WaveData) {
        GameManager.shared.recordWaveCompleted()

        // Check achievements
        AchievementManager.shared.checkWaveAchievements(wave: wave)
        AchievementManager.shared.checkUntouchableWave(damageTakenThisWave: damageTakenThisWave)
        AchievementManager.shared.checkSurvivalAchievements(surviveTime: gameTime)
        AchievementManager.shared.checkDamageAchievements(totalDamage: totalDamageDealt)
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
        // Remove any existing wave notification first
        gameCamera.childNode(withName: "waveNotification")?.removeFromParent()

        let notification = SKNode()
        notification.name = "waveNotification"
        notification.position = CGPoint(x: 0, y: 100)  // Centered above middle of screen
        notification.zPosition = GameConfig.ZPosition.overlay

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

        // Add to camera so it stays on screen
        gameCamera.addChild(notification)

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

        // Track boss kills
        if enemy.isBoss {
            bossKillCount += 1
            AchievementManager.shared.checkBossSlayer(bossKillCount: bossKillCount)
            // Screen shake for boss kills (reduced)
            triggerScreenShake(intensity: 6, duration: 0.2)
            triggerHitFreeze(duration: 0.06)
        }

        // Grant XP to player
        let xpMultiplier = GameManager.shared.getXPMultiplier()
        let xp = Int(CGFloat(enemy.xpValue) * xpMultiplier)
        player.gainXP(xp)
        GameManager.shared.recordXPGained(enemy.xpValue)

        // Update XP bar
        uiManager.updateXP(current: player.stats.currentXP, max: player.stats.xpToNextLevel, level: player.stats.level)

        // Notify wave manager
        waveManager.enemyWasKilled()

        // Check achievements
        AchievementManager.shared.checkKillAchievements(killCount: killCount)
        AchievementManager.shared.checkSpeedrunner(killCount: killCount, timeElapsed: gameTime - waveStartTime)

        // Audio
        AudioManager.shared.playSFX(.enemyDie, on: self)
    }

    func enemyDidShoot(_ enemy: Enemy, projectile: Projectile) {
        // Check if this is a buff signal from a buffer enemy
        if projectile.name == "buff_signal" {
            applyBuffToNearbyEnemies(from: enemy)
            return
        }

        gameLayer.addChild(projectile)
        projectiles.append(projectile)
    }

    private func applyBuffToNearbyEnemies(from buffer: Enemy) {
        let buffRadius = EnemyConfig.Buffer.buffRadius
        let damageMultiplier = 1.0 + EnemyConfig.Buffer.damageBuffPercent
        let speedMultiplier = 1.0 + EnemyConfig.Buffer.speedBuffPercent

        for enemy in enemies {
            guard enemy !== buffer && !enemy.isDead else { continue }

            let dx = enemy.position.x - buffer.position.x
            let dy = enemy.position.y - buffer.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= buffRadius {
                enemy.applyBuff(damageMultiplier: damageMultiplier, speedMultiplier: speedMultiplier)

                // Visual buff beam effect
                showBuffBeam(from: buffer.position, to: enemy.position)
            }
        }

        AudioManager.shared.playSFX(.buffApply, on: self)
    }

    private func showBuffBeam(from start: CGPoint, to end: CGPoint) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let beam = SKShapeNode(path: path)
        beam.strokeColor = SKColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 0.8)
        beam.lineWidth = 3
        beam.glowWidth = 5
        beam.zPosition = GameConfig.ZPosition.effects
        gameLayer.addChild(beam)

        beam.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
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

        // Update health bar if max health changed
        if upgrade.type == .maxHealth {
            uiManager.updateHealth(current: player.stats.currentHealth, max: player.stats.maxHealth)
        }

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
        // Return to main menu
        let transition = SKTransition.fade(withDuration: 0.5)
        let menuScene = MainMenuScene(size: size)
        menuScene.scaleMode = .aspectFill
        view?.presentScene(menuScene, transition: transition)
    }

    func abilityButtonPressed(_ ability: UpgradeType) {
        switch ability {
        case .dash:
            player.activateDash(direction: joystick.currentDirection)
        case .aoeBlast:
            activateAOE()
        case .shield:
            player.activateShield()
        case .timeSlow:
            player.activateTimeSlow()
        case .teleport:
            player.activateTeleport(direction: joystick.currentDirection)
        case .reflect:
            player.activateReflect()
        case .vortex:
            activateVortex()
        default:
            break
        }
    }

    // MARK: - Vortex Ability

    private func activateVortex() {
        player.activateVortex()

        // Pull all enemies toward player then deal damage
        let vortexRadius: CGFloat = 200
        let pullDuration: TimeInterval = 1.0
        let damage = player.stats.damage * 3

        for enemy in enemies {
            let dx = enemy.position.x - player.position.x
            let dy = enemy.position.y - player.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= vortexRadius {
                // Pull enemy toward player
                let pullAction = SKAction.move(to: player.position, duration: pullDuration)
                pullAction.timingMode = .easeIn
                enemy.run(pullAction, withKey: "vortexPull")
            }
        }

        // Deal damage after pull completes
        run(SKAction.sequence([
            SKAction.wait(forDuration: pullDuration + 0.1),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                for enemy in self.enemies {
                    let dx = enemy.position.x - self.player.position.x
                    let dy = enemy.position.y - self.player.position.y
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance <= 50 {  // Close to player after pull
                        enemy.takeDamage(damage)
                        GameManager.shared.recordDamageDealt(Int(damage))
                    }
                }
            }
        ]))

        GameManager.shared.recordAbilityUsed()
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
