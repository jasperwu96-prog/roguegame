//
//  AchievementManager.swift
//  RogueWave
//
//  Handles hidden achievements and milestones
//

import Foundation

// MARK: - Achievement Definition

struct Achievement: Codable {
    let id: String
    let name: String
    let description: String
    let isHidden: Bool
    var isUnlocked: Bool = false
    var unlockedDate: Date?

    // Achievement types for different unlock conditions
    enum AchievementType: String, Codable {
        case kills
        case waves
        case damage
        case surviveTime
        case special
    }

    let type: AchievementType
    let requirement: Int
}

// MARK: - Achievement Manager

class AchievementManager {

    // MARK: - Singleton

    static let shared = AchievementManager()

    // MARK: - Properties

    private var achievements: [String: Achievement] = [:]
    private var recentlyUnlocked: [Achievement] = []
    private let persistenceKey = "unlockedAchievements"

    // Callback for showing achievement unlocks
    var onAchievementUnlocked: ((Achievement) -> Void)?

    // MARK: - Achievement Definitions

    private let allAchievements: [Achievement] = [
        // Kill achievements
        Achievement(id: "first_blood", name: "First Blood", description: "Kill your first enemy", isHidden: false, type: .kills, requirement: 1),
        Achievement(id: "dozen_down", name: "Dozen Down", description: "Kill 12 enemies in one run", isHidden: false, type: .kills, requirement: 12),
        Achievement(id: "century", name: "Century", description: "Kill 100 enemies in one run", isHidden: false, type: .kills, requirement: 100),
        Achievement(id: "mass_murderer", name: "Mass Murderer", description: "Kill 500 enemies in one run", isHidden: true, type: .kills, requirement: 500),
        Achievement(id: "genocide", name: "Unstoppable", description: "Kill 1000 enemies in one run", isHidden: true, type: .kills, requirement: 1000),

        // Wave achievements
        Achievement(id: "survivor", name: "Survivor", description: "Complete wave 5", isHidden: false, type: .waves, requirement: 5),
        Achievement(id: "veteran", name: "Veteran", description: "Complete wave 10", isHidden: false, type: .waves, requirement: 10),
        Achievement(id: "elite", name: "Elite", description: "Complete wave 15", isHidden: true, type: .waves, requirement: 15),
        Achievement(id: "legendary", name: "Legendary", description: "Complete wave 20", isHidden: true, type: .waves, requirement: 20),
        Achievement(id: "immortal", name: "Immortal", description: "Complete wave 30", isHidden: true, type: .waves, requirement: 30),

        // Damage achievements
        Achievement(id: "heavy_hitter", name: "Heavy Hitter", description: "Deal 1000 damage in one run", isHidden: false, type: .damage, requirement: 1000),
        Achievement(id: "destroyer", name: "Destroyer", description: "Deal 10000 damage in one run", isHidden: true, type: .damage, requirement: 10000),
        Achievement(id: "annihilator", name: "Annihilator", description: "Deal 50000 damage in one run", isHidden: true, type: .damage, requirement: 50000),

        // Survival time achievements
        Achievement(id: "minute_man", name: "Minute Man", description: "Survive for 1 minute", isHidden: false, type: .surviveTime, requirement: 60),
        Achievement(id: "five_alive", name: "Five Alive", description: "Survive for 5 minutes", isHidden: false, type: .surviveTime, requirement: 300),
        Achievement(id: "marathon", name: "Marathon", description: "Survive for 10 minutes", isHidden: true, type: .surviveTime, requirement: 600),
        Achievement(id: "endurance", name: "Endurance", description: "Survive for 20 minutes", isHidden: true, type: .surviveTime, requirement: 1200),

        // Special achievements (hidden)
        Achievement(id: "untouchable", name: "Untouchable", description: "Complete a wave without taking damage", isHidden: true, type: .special, requirement: 1),
        Achievement(id: "close_call", name: "Close Call", description: "Survive with less than 5 HP", isHidden: true, type: .special, requirement: 1),
        Achievement(id: "overkill", name: "Overkill", description: "Kill an enemy with 10x overkill damage", isHidden: true, type: .special, requirement: 1),
        Achievement(id: "speedrunner", name: "Speedrunner", description: "Kill 50 enemies in under 30 seconds", isHidden: true, type: .special, requirement: 1),
        Achievement(id: "pacifist_start", name: "Pacifist?", description: "Don't attack for 10 seconds at wave start", isHidden: true, type: .special, requirement: 1),
        Achievement(id: "reflect_master", name: "Mirror Mirror", description: "Reflect 10 projectiles in one Reflect use", isHidden: true, type: .special, requirement: 10),
        Achievement(id: "vortex_massacre", name: "Black Hole", description: "Kill 15 enemies with one Vortex", isHidden: true, type: .special, requirement: 15),
        Achievement(id: "dodge_master", name: "Dodge Master", description: "Dodge 50 enemy projectiles in one run", isHidden: true, type: .special, requirement: 50),
        Achievement(id: "boss_slayer", name: "Boss Slayer", description: "Kill 5 bosses in one run", isHidden: true, type: .special, requirement: 5),
        Achievement(id: "no_upgrades", name: "Purist", description: "Reach wave 5 without taking any upgrades", isHidden: true, type: .special, requirement: 5),
    ]

    // MARK: - Initialization

    private init() {
        loadAchievements()
    }

    private func loadAchievements() {
        // Initialize all achievements
        for achievement in allAchievements {
            achievements[achievement.id] = achievement
        }

        // Load unlocked state from persistence
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let unlockedIds = try? JSONDecoder().decode([String: Date].self, from: data) {
            for (id, date) in unlockedIds {
                if var achievement = achievements[id] {
                    achievement.isUnlocked = true
                    achievement.unlockedDate = date
                    achievements[id] = achievement
                }
            }
        }
    }

    private func saveAchievements() {
        var unlockedIds: [String: Date] = [:]
        for (id, achievement) in achievements where achievement.isUnlocked {
            unlockedIds[id] = achievement.unlockedDate ?? Date()
        }

        if let data = try? JSONEncoder().encode(unlockedIds) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    // MARK: - Achievement Checking

    func checkKillAchievements(killCount: Int) {
        let killAchievements = achievements.filter { $0.value.type == .kills && !$0.value.isUnlocked }
        for (id, achievement) in killAchievements {
            if killCount >= achievement.requirement {
                unlock(achievementId: id)
            }
        }
    }

    func checkWaveAchievements(wave: Int) {
        let waveAchievements = achievements.filter { $0.value.type == .waves && !$0.value.isUnlocked }
        for (id, achievement) in waveAchievements {
            if wave >= achievement.requirement {
                unlock(achievementId: id)
            }
        }
    }

    func checkDamageAchievements(totalDamage: Int) {
        let damageAchievements = achievements.filter { $0.value.type == .damage && !$0.value.isUnlocked }
        for (id, achievement) in damageAchievements {
            if totalDamage >= achievement.requirement {
                unlock(achievementId: id)
            }
        }
    }

    func checkSurvivalAchievements(surviveTime: TimeInterval) {
        let timeAchievements = achievements.filter { $0.value.type == .surviveTime && !$0.value.isUnlocked }
        for (id, achievement) in timeAchievements {
            if Int(surviveTime) >= achievement.requirement {
                unlock(achievementId: id)
            }
        }
    }

    // Special achievement triggers
    func triggerSpecialAchievement(_ id: String) {
        guard let achievement = achievements[id], !achievement.isUnlocked else { return }
        unlock(achievementId: id)
    }

    func checkCloseCall(currentHealth: CGFloat) {
        if currentHealth > 0 && currentHealth < 5 {
            triggerSpecialAchievement("close_call")
        }
    }

    func checkOverkill(damageDealt: CGFloat, enemyHealth: CGFloat) {
        if damageDealt >= enemyHealth * 10 {
            triggerSpecialAchievement("overkill")
        }
    }

    func checkSpeedrunner(killCount: Int, timeElapsed: TimeInterval) {
        if killCount >= 50 && timeElapsed <= 30 {
            triggerSpecialAchievement("speedrunner")
        }
    }

    func checkUntouchableWave(damageTakenThisWave: CGFloat) {
        if damageTakenThisWave == 0 {
            triggerSpecialAchievement("untouchable")
        }
    }

    func checkReflectMaster(reflectedCount: Int) {
        if reflectedCount >= 10 {
            triggerSpecialAchievement("reflect_master")
        }
    }

    func checkVortexMassacre(killCount: Int) {
        if killCount >= 15 {
            triggerSpecialAchievement("vortex_massacre")
        }
    }

    func checkBossSlayer(bossKillCount: Int) {
        if bossKillCount >= 5 {
            triggerSpecialAchievement("boss_slayer")
        }
    }

    // MARK: - Unlock Achievement

    private func unlock(achievementId: String) {
        guard var achievement = achievements[achievementId], !achievement.isUnlocked else { return }

        achievement.isUnlocked = true
        achievement.unlockedDate = Date()
        achievements[achievementId] = achievement

        recentlyUnlocked.append(achievement)
        saveAchievements()

        // Notify listeners
        onAchievementUnlocked?(achievement)

        // Haptic feedback
        AudioManager.shared.triggerSuccessHaptic()
    }

    // MARK: - Getters

    func getAchievement(_ id: String) -> Achievement? {
        return achievements[id]
    }

    func getAllAchievements() -> [Achievement] {
        return Array(achievements.values).sorted { $0.id < $1.id }
    }

    func getUnlockedAchievements() -> [Achievement] {
        return achievements.values.filter { $0.isUnlocked }
    }

    func getLockedAchievements(includeHidden: Bool = false) -> [Achievement] {
        return achievements.values.filter { !$0.isUnlocked && (includeHidden || !$0.isHidden) }
    }

    func getRecentlyUnlocked() -> [Achievement] {
        let recent = recentlyUnlocked
        recentlyUnlocked.removeAll()
        return recent
    }

    func getProgress() -> (unlocked: Int, total: Int) {
        let unlocked = achievements.values.filter { $0.isUnlocked }.count
        return (unlocked, achievements.count)
    }

    // MARK: - Reset (for testing)

    func resetAllAchievements() {
        for id in achievements.keys {
            achievements[id]?.isUnlocked = false
            achievements[id]?.unlockedDate = nil
        }
        recentlyUnlocked.removeAll()
        saveAchievements()
    }
}
