//
//  WaveManager.swift
//  RogueWave
//
//  Manages wave spawning, difficulty scaling, and wave progression
//

import SpriteKit

// MARK: - Wave Data Structure

struct WaveData {
    let waveNumber: Int
    var enemySpawns: [(type: EnemyType, count: Int)]
    var modifiers: [WaveModifier]
    var isBossWave: Bool
    var totalEnemies: Int {
        return enemySpawns.reduce(0) { $0 + $1.count }
    }
}

// MARK: - Wave Manager Delegate

protocol WaveManagerDelegate: AnyObject {
    func waveDidStart(wave: Int, data: WaveData)
    func waveDidEnd(wave: Int, data: WaveData)
    func shouldSpawnEnemy(type: EnemyType, isElite: Bool, isBoss: Bool) -> Enemy?
    func waveTimerUpdated(timeRemaining: TimeInterval)
    func allEnemiesDefeated()
}

// MARK: - Wave Manager Class

class WaveManager {

    // MARK: - Properties

    weak var delegate: WaveManagerDelegate?

    // Wave state
    private(set) var currentWave: Int = 0
    private(set) var isWaveActive: Bool = false
    private(set) var currentWaveData: WaveData?

    // Timing
    private var waveTimer: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var spawnInterval: TimeInterval = EnemyConfig.spawnInterval

    // Spawn tracking
    private var enemiesToSpawn: [(type: EnemyType, isElite: Bool)] = []
    private var enemiesSpawned: Int = 0
    private var enemiesKilled: Int = 0
    private var totalEnemiesInWave: Int = 0

    // Active modifiers
    private(set) var activeModifiers: [WaveModifier] = []

    // Spawn bounds
    var spawnBounds: CGRect = .zero

    // MARK: - Initialization

    init() {}

    // MARK: - Wave Control

    func startNextWave() {
        currentWave += 1

        // Generate wave data
        let waveData = generateWaveData(for: currentWave)
        currentWaveData = waveData

        // Setup spawn queue
        setupSpawnQueue(from: waveData)

        // Apply modifiers
        activeModifiers = waveData.modifiers

        // Reset timers
        waveTimer = WaveConfig.waveDuration
        spawnTimer = 0
        enemiesSpawned = 0
        enemiesKilled = 0
        totalEnemiesInWave = waveData.totalEnemies

        // Update spawn interval based on wave
        spawnInterval = max(0.2, EnemyConfig.spawnInterval - CGFloat(currentWave) * 0.02)

        isWaveActive = true

        delegate?.waveDidStart(wave: currentWave, data: waveData)
    }

    func endWave() {
        isWaveActive = false

        if let waveData = currentWaveData {
            delegate?.waveDidEnd(wave: currentWave, data: waveData)
        }

        activeModifiers.removeAll()
    }

    func reset() {
        currentWave = 0
        isWaveActive = false
        currentWaveData = nil
        enemiesToSpawn.removeAll()
        activeModifiers.removeAll()
        waveTimer = 0
        spawnTimer = 0
        enemiesSpawned = 0
        enemiesKilled = 0
        totalEnemiesInWave = 0
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentEnemyCount: Int) {
        guard isWaveActive else { return }

        // Update wave timer
        waveTimer -= deltaTime
        delegate?.waveTimerUpdated(timeRemaining: Swift.max(0, waveTimer))

        // Spawn enemies continuously while wave is active
        if !enemiesToSpawn.isEmpty && currentEnemyCount < EnemyConfig.maxEnemiesOnScreen {
            spawnTimer += deltaTime

            if spawnTimer >= spawnInterval {
                spawnTimer = 0
                spawnNextEnemy()
            }
        }

        // Check wave completion conditions
        checkWaveCompletion(currentEnemyCount: currentEnemyCount)
    }

    // MARK: - Wave Generation

    private func generateWaveData(for wave: Int) -> WaveData {
        var enemySpawns: [(EnemyType, Int)] = []
        var modifiers: [WaveModifier] = []
        let isBossWave = wave % WaveConfig.bossWaveInterval == 0

        // Use predefined spawns for first 3 waves
        if wave == 1 {
            enemySpawns = WaveConfig.wave1Enemies
        } else if wave == 2 {
            enemySpawns = WaveConfig.wave2Enemies
        } else if wave == 3 {
            enemySpawns = WaveConfig.wave3Enemies
        } else {
            // Generate procedural wave composition
            enemySpawns = generateProceduralSpawns(for: wave)
        }

        // Add modifiers for later waves
        if wave > 3 && CGFloat.random(in: 0...1) < WaveConfig.modifierChance {
            if let randomModifier = WaveModifier.allCases.randomElement() {
                modifiers.append(randomModifier)
            }
        }

        // Boss waves always have elite modifier
        if isBossWave {
            modifiers.append(.elite)
        }

        return WaveData(
            waveNumber: wave,
            enemySpawns: enemySpawns,
            modifiers: modifiers,
            isBossWave: isBossWave
        )
    }

    private func generateProceduralSpawns(for wave: Int) -> [(EnemyType, Int)] {
        var spawns: [(EnemyType, Int)] = []

        // Calculate total enemy count based on wave
        let baseCount = WaveConfig.baseEnemyCount
        let scaledCount = Int(CGFloat(baseCount) * pow(WaveConfig.enemyCountScaling, CGFloat(wave - 1)))
        let totalCount = min(scaledCount, 50)  // Cap at 50 enemies

        // Distribute among enemy types based on wave progression
        var remaining = totalCount

        // Always have some chasers
        let chaserCount = max(2, Int(CGFloat(totalCount) * 0.4))
        spawns.append((.chaser, chaserCount))
        remaining -= chaserCount

        // Add swarm enemies
        if wave >= 2 && remaining > 0 {
            let swarmCount = min(remaining, Int(CGFloat(totalCount) * 0.3))
            spawns.append((.swarm, swarmCount))
            remaining -= swarmCount
        }

        // Add ranged enemies
        if wave >= 3 && remaining > 0 {
            let rangedCount = min(remaining, max(1, Int(CGFloat(totalCount) * 0.15)))
            spawns.append((.ranged, rangedCount))
            remaining -= rangedCount
        }

        // Add tank enemies
        if wave >= 4 && remaining > 0 {
            let tankCount = min(remaining, max(1, Int(CGFloat(totalCount) * 0.1)))
            spawns.append((.tank, tankCount))
            remaining -= tankCount
        }

        // Any remaining go to chasers
        if remaining > 0 {
            if let index = spawns.firstIndex(where: { $0.0 == .chaser }) {
                spawns[index].1 += remaining
            }
        }

        return spawns
    }

    private func setupSpawnQueue(from waveData: WaveData) {
        enemiesToSpawn.removeAll()

        // Calculate elite chance for this wave
        let eliteChance = WaveConfig.eliteChancePerWave * CGFloat(waveData.waveNumber)
        let hasEliteModifier = waveData.modifiers.contains(.elite)
        let adjustedEliteChance = hasEliteModifier ? eliteChance * WaveModifier.elite.multiplier : eliteChance

        // Build spawn queue
        for (type, count) in waveData.enemySpawns {
            for _ in 0..<count {
                let isElite = CGFloat.random(in: 0...1) < adjustedEliteChance
                enemiesToSpawn.append((type, isElite))
            }
        }

        // Shuffle spawn order
        enemiesToSpawn.shuffle()

        // Add boss at the end if it's a boss wave
        if waveData.isBossWave {
            let bossType: EnemyType = [.chaser, .tank].randomElement() ?? .chaser
            enemiesToSpawn.append((bossType, false))  // Boss flag handled separately
        }
    }

    // MARK: - Spawning

    private func spawnNextEnemy() {
        guard !enemiesToSpawn.isEmpty else { return }

        let spawnData = enemiesToSpawn.removeFirst()

        // Check if this is the boss (last enemy in boss wave)
        let isBoss = currentWaveData?.isBossWave == true && enemiesToSpawn.isEmpty

        // Request enemy spawn from delegate
        if let enemy = delegate?.shouldSpawnEnemy(type: spawnData.type, isElite: spawnData.isElite, isBoss: isBoss) {
            // Apply wave modifiers to enemy
            applyModifiers(to: enemy)

            enemiesSpawned += 1
        }
    }

    private func applyModifiers(to enemy: Enemy) {
        for modifier in activeModifiers {
            switch modifier {
            case .speedBoost:
                enemy.moveSpeed *= modifier.multiplier
            case .healthBoost:
                enemy.maxHealth *= modifier.multiplier
                enemy.currentHealth = enemy.maxHealth
            case .damageBoost:
                enemy.damage *= modifier.multiplier
            case .regen:
                enemy.regenRate = enemy.maxHealth * 0.02  // 2% health per second
            case .swarm, .elite:
                // Handled during spawn queue generation
                break
            }
        }
    }

    // MARK: - Enemy Tracking

    func enemyWasKilled() {
        enemiesKilled += 1
    }

    private func checkWaveCompletion(currentEnemyCount: Int) {
        let allEnemiesSpawned = enemiesToSpawn.isEmpty
        let allEnemiesKilled = enemiesKilled >= enemiesSpawned && enemiesSpawned > 0

        // Wave ends when:
        // 1. All enemies have been spawned AND all are killed, OR
        // 2. Timer runs out AND all current enemies on screen are dead
        if allEnemiesSpawned && allEnemiesKilled && currentEnemyCount == 0 {
            endWaveAndNotify()
            return
        }

        // Timer ran out - stop spawning new enemies, wait for current to be killed
        if waveTimer <= 0 {
            enemiesToSpawn.removeAll()

            // If no enemies left on screen, wave is complete
            if currentEnemyCount == 0 {
                endWaveAndNotify()
            }
        }
    }

    private func endWaveAndNotify() {
        guard isWaveActive else { return }
        isWaveActive = false
        delegate?.allEnemiesDefeated()
    }

    // MARK: - Spawn Position Generation

    func generateSpawnPosition() -> CGPoint {
        guard spawnBounds != .zero else { return .zero }

        // Spawn from edges of screen
        let edge = Int.random(in: 0...3)
        var x: CGFloat = 0
        var y: CGFloat = 0

        let padding = EnemyConfig.spawnPadding

        switch edge {
        case 0: // Top
            x = CGFloat.random(in: spawnBounds.minX...spawnBounds.maxX)
            y = spawnBounds.maxY + padding
        case 1: // Bottom
            x = CGFloat.random(in: spawnBounds.minX...spawnBounds.maxX)
            y = spawnBounds.minY - padding
        case 2: // Left
            x = spawnBounds.minX - padding
            y = CGFloat.random(in: spawnBounds.minY...spawnBounds.maxY)
        case 3: // Right
            x = spawnBounds.maxX + padding
            y = CGFloat.random(in: spawnBounds.minY...spawnBounds.maxY)
        default:
            break
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Wave Info

    func getWaveProgress() -> (spawned: Int, killed: Int, total: Int) {
        return (enemiesSpawned, enemiesKilled, totalEnemiesInWave)
    }

    func getActiveModifierNames() -> [String] {
        return activeModifiers.map { $0.displayName }
    }

    func isLastWaveEnemy() -> Bool {
        return enemiesToSpawn.isEmpty
    }
}

// MARK: - Wave Summary Data

struct WaveSummary {
    let waveNumber: Int
    let enemiesKilled: Int
    let timeTaken: TimeInterval
    let modifiers: [WaveModifier]
    let isBossWave: Bool

    var scoreBonus: Int {
        var bonus = enemiesKilled * 10
        if isBossWave { bonus += 500 }
        bonus += modifiers.count * 100
        return bonus
    }
}
