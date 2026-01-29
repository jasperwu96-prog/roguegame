//
//  GameManager.swift
//  RogueWave
//
//  Manages game state, persistence, and meta-progression between runs
//

import Foundation

// MARK: - Persistent Data Structures

struct MetaProgression: Codable {
    var totalGold: Int = 0
    var highestWave: Int = 0
    var totalKills: Int = 0
    var totalRuns: Int = 0
    var totalPlayTime: TimeInterval = 0

    // Permanent upgrades purchased with gold
    var permanentUpgrades: [PermanentUpgrade: Int] = [:]

    // Unlocked content
    var unlockedCharacters: Set<String> = ["default"]
    var unlockedAbilities: Set<UpgradeType> = []

    // Achievements
    var achievements: Set<String> = []
}

enum PermanentUpgrade: String, Codable, CaseIterable {
    case startingHealth      // +10% starting health per level
    case startingDamage      // +5% starting damage per level
    case startingSpeed       // +5% starting speed per level
    case goldBonus           // +10% gold earned per level
    case xpBonus             // +10% XP earned per level
    case rerollUpgrades      // Allows rerolling upgrade choices

    var displayName: String {
        switch self {
        case .startingHealth: return "Vitality"
        case .startingDamage: return "Power"
        case .startingSpeed: return "Swiftness"
        case .goldBonus: return "Greed"
        case .xpBonus: return "Wisdom"
        case .rerollUpgrades: return "Second Chance"
        }
    }

    var description: String {
        switch self {
        case .startingHealth: return "+10% starting HP"
        case .startingDamage: return "+5% starting damage"
        case .startingSpeed: return "+5% starting speed"
        case .goldBonus: return "+10% gold earned"
        case .xpBonus: return "+10% XP earned"
        case .rerollUpgrades: return "Reroll upgrades"
        }
    }

    var maxLevel: Int {
        switch self {
        case .startingHealth, .startingDamage, .startingSpeed:
            return 10
        case .goldBonus, .xpBonus:
            return 5
        case .rerollUpgrades:
            return 3
        }
    }

    func cost(forLevel level: Int) -> Int {
        let baseCost: Int
        switch self {
        case .startingHealth, .startingDamage, .startingSpeed:
            baseCost = 100
        case .goldBonus, .xpBonus:
            baseCost = 200
        case .rerollUpgrades:
            baseCost = 500
        }
        return baseCost * (level + 1)
    }
}

// MARK: - Run Statistics

struct RunStatistics: Codable {
    var wavesCompleted: Int = 0
    var enemiesKilled: Int = 0
    var damageDealt: Int = 0
    var damageTaken: Int = 0
    var goldEarned: Int = 0
    var xpEarned: Int = 0
    var upgradesCollected: Int = 0
    var abilitiesUsed: Int = 0
    var criticalHits: Int = 0
    var timeSurvived: TimeInterval = 0
    var highestCombo: Int = 0
}

// MARK: - Game Manager Singleton

class GameManager {

    // MARK: - Singleton

    static let shared = GameManager()

    private init() {
        loadProgress()
    }

    // MARK: - Properties

    private(set) var metaProgression = MetaProgression()
    private(set) var currentRunStats = RunStatistics()

    // Settings
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var vibrationEnabled: Bool = true
    var screenShakeEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: "screenShakeEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "screenShakeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "screenShakeEnabled")
        }
    }

    // Current run state
    var isRunActive: Bool = false

    // MARK: - Persistence

    private let userDefaults = UserDefaults.standard
    private let progressKey = "roguewave_progress"
    private let settingsKey = "roguewave_settings"

    func saveProgress() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(metaProgression)
            userDefaults.set(data, forKey: progressKey)
            userDefaults.synchronize()
        } catch {
            print("Failed to save progress: \(error)")
        }
    }

    func loadProgress() {
        guard let data = userDefaults.data(forKey: progressKey) else {
            metaProgression = MetaProgression()
            return
        }

        do {
            let decoder = JSONDecoder()
            metaProgression = try decoder.decode(MetaProgression.self, from: data)
        } catch {
            print("Failed to load progress: \(error)")
            metaProgression = MetaProgression()
        }
    }

    func resetProgress() {
        metaProgression = MetaProgression()
        saveProgress()
    }

    func resetAllProgress() {
        metaProgression = MetaProgression()
        currentRunStats = RunStatistics()
        saveProgress()
    }

    // MARK: - Run Management

    func startNewRun() {
        isRunActive = true
        currentRunStats = RunStatistics()
        metaProgression.totalRuns += 1
    }

    func endRun() {
        guard isRunActive else { return }

        isRunActive = false

        // Update meta progression with run results
        metaProgression.totalKills += currentRunStats.enemiesKilled
        metaProgression.totalPlayTime += currentRunStats.timeSurvived

        // Calculate gold earned (with bonus from permanent upgrades)
        let goldMultiplier = 1.0 + CGFloat(metaProgression.permanentUpgrades[.goldBonus] ?? 0) * 0.1
        let goldFromKills = currentRunStats.enemiesKilled * 1
        let goldFromWaves = currentRunStats.wavesCompleted * 10
        let totalGold = Int(CGFloat(goldFromKills + goldFromWaves) * goldMultiplier)

        metaProgression.totalGold += totalGold
        currentRunStats.goldEarned = totalGold

        // Update high score
        if currentRunStats.wavesCompleted > metaProgression.highestWave {
            metaProgression.highestWave = currentRunStats.wavesCompleted
        }

        // Check achievements
        checkAchievements()

        // Save
        saveProgress()
    }

    // MARK: - Permanent Upgrades

    func purchaseUpgrade(_ upgrade: PermanentUpgrade) -> Bool {
        let currentLevel = metaProgression.permanentUpgrades[upgrade] ?? 0

        guard currentLevel < upgrade.maxLevel else { return false }

        let cost = upgrade.cost(forLevel: currentLevel)

        guard metaProgression.totalGold >= cost else { return false }

        metaProgression.totalGold -= cost
        metaProgression.permanentUpgrades[upgrade] = currentLevel + 1

        saveProgress()
        return true
    }

    func getUpgradeLevel(_ upgrade: PermanentUpgrade) -> Int {
        return metaProgression.permanentUpgrades[upgrade] ?? 0
    }

    func canAffordUpgrade(_ upgrade: PermanentUpgrade) -> Bool {
        let currentLevel = metaProgression.permanentUpgrades[upgrade] ?? 0
        guard currentLevel < upgrade.maxLevel else { return false }
        return metaProgression.totalGold >= upgrade.cost(forLevel: currentLevel)
    }

    // MARK: - Starting Stats with Permanent Upgrades

    func getStartingHealthBonus() -> CGFloat {
        let level = CGFloat(metaProgression.permanentUpgrades[.startingHealth] ?? 0)
        return 1.0 + level * 0.1
    }

    func getStartingDamageBonus() -> CGFloat {
        let level = CGFloat(metaProgression.permanentUpgrades[.startingDamage] ?? 0)
        return 1.0 + level * 0.05
    }

    func getStartingSpeedBonus() -> CGFloat {
        let level = CGFloat(metaProgression.permanentUpgrades[.startingSpeed] ?? 0)
        return 1.0 + level * 0.05
    }

    func getXPMultiplier() -> CGFloat {
        let level = CGFloat(metaProgression.permanentUpgrades[.xpBonus] ?? 0)
        return 1.0 + level * 0.1
    }

    func getRerollCount() -> Int {
        return metaProgression.permanentUpgrades[.rerollUpgrades] ?? 0
    }

    // MARK: - Run Statistics Tracking

    func recordKill() {
        currentRunStats.enemiesKilled += 1
    }

    func recordDamageDealt(_ damage: Int) {
        currentRunStats.damageDealt += damage
    }

    func recordDamageTaken(_ damage: Int) {
        currentRunStats.damageTaken += damage
    }

    func recordWaveCompleted() {
        currentRunStats.wavesCompleted += 1
    }

    func recordUpgradeCollected() {
        currentRunStats.upgradesCollected += 1
    }

    func recordAbilityUsed() {
        currentRunStats.abilitiesUsed += 1
    }

    func recordCriticalHit() {
        currentRunStats.criticalHits += 1
    }

    func recordXPGained(_ xp: Int) {
        let xpMultiplier = getXPMultiplier()
        currentRunStats.xpEarned += Int(CGFloat(xp) * xpMultiplier)
    }

    func updateSurvivedTime(_ time: TimeInterval) {
        currentRunStats.timeSurvived = time
    }

    // MARK: - Achievements

    private func checkAchievements() {
        // First run
        if metaProgression.totalRuns == 1 {
            unlockAchievement("first_run")
        }

        // Kill milestones
        if metaProgression.totalKills >= 100 {
            unlockAchievement("kill_100")
        }
        if metaProgression.totalKills >= 1000 {
            unlockAchievement("kill_1000")
        }
        if metaProgression.totalKills >= 10000 {
            unlockAchievement("kill_10000")
        }

        // Wave milestones
        if metaProgression.highestWave >= 5 {
            unlockAchievement("wave_5")
        }
        if metaProgression.highestWave >= 10 {
            unlockAchievement("wave_10")
        }
        if metaProgression.highestWave >= 20 {
            unlockAchievement("wave_20")
        }
        if metaProgression.highestWave >= 50 {
            unlockAchievement("wave_50")
        }

        // Run count milestones
        if metaProgression.totalRuns >= 10 {
            unlockAchievement("runs_10")
        }
        if metaProgression.totalRuns >= 50 {
            unlockAchievement("runs_50")
        }
        if metaProgression.totalRuns >= 100 {
            unlockAchievement("runs_100")
        }

        // Single run achievements
        if currentRunStats.enemiesKilled >= 100 {
            unlockAchievement("single_run_100_kills")
        }
        if currentRunStats.wavesCompleted >= 10 && currentRunStats.damageTaken == 0 {
            unlockAchievement("no_damage_10_waves")
        }
    }

    private func unlockAchievement(_ id: String) {
        if !metaProgression.achievements.contains(id) {
            metaProgression.achievements.insert(id)
            // Could trigger notification here
            print("Achievement unlocked: \(id)")
        }
    }

    func hasAchievement(_ id: String) -> Bool {
        return metaProgression.achievements.contains(id)
    }

    // MARK: - Leaderboard Data

    func getLeaderboardData() -> [String: Any] {
        return [
            "highestWave": metaProgression.highestWave,
            "totalKills": metaProgression.totalKills,
            "totalRuns": metaProgression.totalRuns,
            "totalPlayTime": metaProgression.totalPlayTime
        ]
    }
}
