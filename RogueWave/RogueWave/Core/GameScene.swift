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

    // Statistics
    private var killCount: Int = 0
    private var rerollsRemaining: Int = 0

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        setupScene()
        setupPhysics()
        setupLayers()
        setupPlayer()
        setupJoystick()
        setupSystems()
        setupUI()

        // Start the game
        startGame()
    }

    // MARK: - Setup Methods

    private func setupScene() {
        backgroundColor = UIConfig.backgroundColor
        anchorPoint = CGPoint(x: 0, y: 0)

        // Initialize object pools
        ObjectPool.shared.initialize()
    }

    private func setupPhysics() {
        // Minimal physics for performance
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // Create arena boundaries
        let boundaryRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let boundary = SKPhysicsBody(edgeLoopFrom: boundaryRect)
        boundary.categoryBitMask = GameConfig.PhysicsCategory.boundary
        boundary.collisionBitMask = GameConfig.PhysicsCategory.player | GameConfig.PhysicsCategory.enemy
        boundary.friction = 0
        physicsBody = boundary
    }

    private func setupLayers() {
        // Background layer
        backgroundLayer = SKNode()
        backgroundLayer.zPosition = GameConfig.ZPosition.background
        addChild(backgroundLayer)

        // Create grid pattern for visual reference
        createBackgroundGrid()

        // Game layer (contains player, enemies, projectiles)
        gameLayer = SKNode()
        gameLayer.zPosition = GameConfig.ZPosition.floor
        addChild(gameLayer)
    }

    private func createBackgroundGrid() {
        // Create a dungeon/arena style background

        // Dark stone floor base
        let floorBase = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        floorBase.fillColor = SKColor(red: 0.12, green: 0.1, blue: 0.15, alpha: 1.0)
        floorBase.strokeColor = .clear
        floorBase.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundLayer.addChild(floorBase)

        // Stone tile pattern
        let tileSize: CGFloat = 60
        let tileColors = [
            SKColor(red: 0.15, green: 0.12, blue: 0.18, alpha: 1.0),
            SKColor(red: 0.13, green: 0.11, blue: 0.16, alpha: 1.0),
            SKColor(red: 0.14, green: 0.12, blue: 0.17, alpha: 1.0)
        ]

        var tileX: CGFloat = tileSize / 2
        var row = 0
        while tileX < size.width + tileSize {
            var tileY: CGFloat = tileSize / 2
            while tileY < size.height + tileSize {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2), cornerRadius: 3)
                tile.fillColor = tileColors[(row + Int(tileY / tileSize)) % tileColors.count]
                tile.strokeColor = SKColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 0.8)
                tile.lineWidth = 1
                tile.position = CGPoint(x: tileX, y: tileY)
                backgroundLayer.addChild(tile)

                // Random cracks/details on some tiles
                if Int.random(in: 0...5) == 0 {
                    let crack = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 10...25), height: 1))
                    crack.fillColor = SKColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 0.5)
                    crack.strokeColor = .clear
                    crack.zRotation = CGFloat.random(in: -.pi/4 ... .pi/4)
                    crack.position = CGPoint(
                        x: CGFloat.random(in: -tileSize/4 ... tileSize/4),
                        y: CGFloat.random(in: -tileSize/4 ... tileSize/4)
                    )
                    tile.addChild(crack)
                }

                tileY += tileSize
            }
            tileX += tileSize
            row += 1
        }

        // Arena border/walls
        let borderWidth: CGFloat = 15
        let borderColor = SKColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 1.0)
        let borderHighlight = SKColor(red: 0.35, green: 0.28, blue: 0.2, alpha: 1.0)

        // Top border
        let topBorder = SKShapeNode(rectOf: CGSize(width: size.width, height: borderWidth))
        topBorder.fillColor = borderColor
        topBorder.strokeColor = borderHighlight
        topBorder.lineWidth = 2
        topBorder.position = CGPoint(x: size.width / 2, y: size.height - borderWidth / 2)
        backgroundLayer.addChild(topBorder)

        // Bottom border
        let bottomBorder = SKShapeNode(rectOf: CGSize(width: size.width, height: borderWidth))
        bottomBorder.fillColor = borderColor
        bottomBorder.strokeColor = borderHighlight
        bottomBorder.lineWidth = 2
        bottomBorder.position = CGPoint(x: size.width / 2, y: borderWidth / 2)
        backgroundLayer.addChild(bottomBorder)

        // Left border
        let leftBorder = SKShapeNode(rectOf: CGSize(width: borderWidth, height: size.height))
        leftBorder.fillColor = borderColor
        leftBorder.strokeColor = borderHighlight
        leftBorder.lineWidth = 2
        leftBorder.position = CGPoint(x: borderWidth / 2, y: size.height / 2)
        backgroundLayer.addChild(leftBorder)

        // Right border
        let rightBorder = SKShapeNode(rectOf: CGSize(width: borderWidth, height: size.height))
        rightBorder.fillColor = borderColor
        rightBorder.strokeColor = borderHighlight
        rightBorder.lineWidth = 2
        rightBorder.position = CGPoint(x: size.width - borderWidth / 2, y: size.height / 2)
        backgroundLayer.addChild(rightBorder)

        // Corner decorations (torch holders)
        let cornerPositions = [
            CGPoint(x: 40, y: size.height - 100),
            CGPoint(x: size.width - 40, y: size.height - 100),
            CGPoint(x: 40, y: 100),
            CGPoint(x: size.width - 40, y: 100)
        ]

        for pos in cornerPositions {
            // Torch base
            let torchBase = SKShapeNode(rectOf: CGSize(width: 20, height: 30), cornerRadius: 3)
            torchBase.fillColor = SKColor(red: 0.3, green: 0.25, blue: 0.15, alpha: 1.0)
            torchBase.strokeColor = SKColor(red: 0.4, green: 0.35, blue: 0.25, alpha: 1.0)
            torchBase.lineWidth = 2
            torchBase.position = pos
            backgroundLayer.addChild(torchBase)

            // Torch flame glow
            let glow = SKShapeNode(circleOfRadius: 25)
            glow.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.15)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: pos.x, y: pos.y + 25)
            backgroundLayer.addChild(glow)

            // Flame
            let flamePath = CGMutablePath()
            flamePath.move(to: CGPoint(x: -8, y: 0))
            flamePath.addQuadCurve(to: CGPoint(x: 0, y: 25), control: CGPoint(x: -10, y: 15))
            flamePath.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 10, y: 15))
            flamePath.closeSubpath()

            let flame = SKShapeNode(path: flamePath)
            flame.fillColor = SKColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.9)
            flame.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
            flame.lineWidth = 1
            flame.glowWidth = 5
            flame.position = CGPoint(x: pos.x, y: pos.y + 15)
            backgroundLayer.addChild(flame)

            // Animate flame flicker
            let flicker = SKAction.sequence([
                SKAction.scaleX(to: 1.1, duration: 0.2),
                SKAction.scaleX(to: 0.9, duration: 0.15),
                SKAction.scaleX(to: 1.0, duration: 0.1)
            ])
            flame.run(SKAction.repeatForever(flicker))
        }

        // Center arena circle decoration
        let centerCircle = SKShapeNode(circleOfRadius: 80)
        centerCircle.fillColor = .clear
        centerCircle.strokeColor = SKColor(red: 0.2, green: 0.18, blue: 0.15, alpha: 0.5)
        centerCircle.lineWidth = 3
        centerCircle.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundLayer.addChild(centerCircle)

        let innerCircle = SKShapeNode(circleOfRadius: 60)
        innerCircle.fillColor = .clear
        innerCircle.strokeColor = SKColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 0.4)
        innerCircle.lineWidth = 2
        innerCircle.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundLayer.addChild(innerCircle)

        // Subtle vignette effect (darker corners)
        let vignetteSize = Swift.max(size.width, size.height) * 1.5
        let vignette = SKShapeNode(circleOfRadius: vignetteSize / 2)
        vignette.fillColor = .clear
        vignette.strokeColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.4)
        vignette.lineWidth = vignetteSize * 0.3
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.zPosition = GameConfig.ZPosition.background + 0.5
        backgroundLayer.addChild(vignette)
    }

    private func setupPlayer() {
        player = Player()
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        player.delegate = self
        gameLayer.addChild(player)

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
        joystick.position = UIConfig.joystickPosition
        addChild(joystick)

        // Touch zone covers left half of screen
        let touchZoneRect = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
        joystickTouchZone = JoystickTouchZone(rect: touchZoneRect, joystick: joystick)
        joystickTouchZone.zPosition = GameConfig.ZPosition.ui - 1
        addChild(joystickTouchZone)
    }

    private func setupSystems() {
        // Wave manager
        waveManager = WaveManager()
        waveManager.delegate = self
        waveManager.spawnBounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        // Upgrade system
        upgradeSystem = UpgradeSystem()
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

        // Reset player
        player.reset(at: CGPoint(x: size.width / 2, y: size.height / 2))
        applyPermanentUpgrades()

        // Reset systems
        upgradeSystem.resetForNewRun()
        uiManager.reset()

        // Start new game
        startGame()
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
        updateEnemies(deltaTime: deltaTime)
        updateProjectiles(deltaTime: deltaTime)
        updateWaveManager(deltaTime: deltaTime)

        // Update statistics
        GameManager.shared.updateSurvivedTime(gameTime)
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
