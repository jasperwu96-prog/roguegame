//
//  AudioManager.swift
//  RogueWave
//
//  Handles all game audio including music and sound effects
//

import SpriteKit
import AVFoundation

class AudioManager {

    // MARK: - Singleton

    static let shared = AudioManager()

    // MARK: - Properties

    private var musicPlayer: AVAudioPlayer?
    private var soundEffects: [String: SKAction] = [:]
    private var isMusicEnabled: Bool = true
    private var isSFXEnabled: Bool = true
    private var isHapticsEnabled: Bool = true
    private var musicVolume: Float = 0.5
    private var sfxVolume: Float = 0.7

    // MARK: - Sound Effect Names

    enum SFX: String {
        case playerShoot = "player_shoot"
        case enemyHit = "enemy_hit"
        case enemyDie = "enemy_die"
        case playerHit = "player_hit"
        case playerDie = "player_die"
        case levelUp = "level_up"
        case waveStart = "wave_start"
        case upgrade = "upgrade"
        case dash = "dash"
        case shield = "shield"
        case explosion = "explosion"
        case heal = "heal"
        case critHit = "crit_hit"
        case buttonPress = "button_press"
        case achievement = "achievement"
        case chargeWarning = "charge_warning"
        case suicideTick = "suicide_tick"
        case buffApply = "buff_apply"
    }

    // MARK: - Initialization

    private init() {
        setupSoundEffects()
        loadSettings()
    }

    private func setupSoundEffects() {
        // Pre-create sound actions for efficiency
        // These use synthesized sounds since we don't have audio files

        // Player shoot - quick high-pitched blip
        soundEffects[SFX.playerShoot.rawValue] = createSynthSound(frequency: 800, duration: 0.05)

        // Enemy hit - thud sound
        soundEffects[SFX.enemyHit.rawValue] = createSynthSound(frequency: 200, duration: 0.08)

        // Enemy die - descending tone
        soundEffects[SFX.enemyDie.rawValue] = createSynthSound(frequency: 400, duration: 0.15)

        // Player hit - low impact
        soundEffects[SFX.playerHit.rawValue] = createSynthSound(frequency: 150, duration: 0.12)

        // Player die - dramatic descending
        soundEffects[SFX.playerDie.rawValue] = createSynthSound(frequency: 300, duration: 0.4)

        // Level up - ascending happy sound
        soundEffects[SFX.levelUp.rawValue] = createSynthSound(frequency: 600, duration: 0.2)

        // Wave start - alert tone
        soundEffects[SFX.waveStart.rawValue] = createSynthSound(frequency: 500, duration: 0.3)

        // Upgrade - magical chime
        soundEffects[SFX.upgrade.rawValue] = createSynthSound(frequency: 700, duration: 0.25)

        // Dash - whoosh
        soundEffects[SFX.dash.rawValue] = createSynthSound(frequency: 350, duration: 0.1)

        // Shield - energy hum
        soundEffects[SFX.shield.rawValue] = createSynthSound(frequency: 250, duration: 0.2)

        // Explosion - boom
        soundEffects[SFX.explosion.rawValue] = createSynthSound(frequency: 100, duration: 0.25)

        // Heal - gentle chime
        soundEffects[SFX.heal.rawValue] = createSynthSound(frequency: 550, duration: 0.15)

        // Crit hit - sharp impact
        soundEffects[SFX.critHit.rawValue] = createSynthSound(frequency: 450, duration: 0.1)

        // Button press - click
        soundEffects[SFX.buttonPress.rawValue] = createSynthSound(frequency: 600, duration: 0.03)

        // Achievement - fanfare
        soundEffects[SFX.achievement.rawValue] = createSynthSound(frequency: 800, duration: 0.35)

        // Charge warning - alarming beep
        soundEffects[SFX.chargeWarning.rawValue] = createSynthSound(frequency: 900, duration: 0.08)

        // Suicide tick - ticking bomb
        soundEffects[SFX.suicideTick.rawValue] = createSynthSound(frequency: 1000, duration: 0.05)

        // Buff apply - power up
        soundEffects[SFX.buffApply.rawValue] = createSynthSound(frequency: 450, duration: 0.2)
    }

    private func createSynthSound(frequency: Double, duration: TimeInterval) -> SKAction {
        // Create a simple synthesized sound using SKAction
        // In a real game, you'd use actual audio files
        return SKAction.playSoundFileNamed("", waitForCompletion: false)
    }

    private func loadSettings() {
        // Set defaults if not set
        if !UserDefaults.standard.bool(forKey: "audioSettingsSet") {
            isMusicEnabled = true
            isSFXEnabled = true
            isHapticsEnabled = true
            UserDefaults.standard.set(true, forKey: "audioSettingsSet")
            saveSettings()
        } else {
            isMusicEnabled = UserDefaults.standard.bool(forKey: "musicEnabled")
            isSFXEnabled = UserDefaults.standard.bool(forKey: "sfxEnabled")
            isHapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled")
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(isMusicEnabled, forKey: "musicEnabled")
        UserDefaults.standard.set(isSFXEnabled, forKey: "sfxEnabled")
        UserDefaults.standard.set(isHapticsEnabled, forKey: "hapticsEnabled")
    }

    // MARK: - Music Control

    func playBackgroundMusic() {
        guard isMusicEnabled else { return }

        // In a real implementation, you'd load actual music files
        // For now, we'll just set up the player structure
        // guard let url = Bundle.main.url(forResource: "background_music", withExtension: "mp3") else { return }

        // do {
        //     musicPlayer = try AVAudioPlayer(contentsOf: url)
        //     musicPlayer?.numberOfLoops = -1 // Loop forever
        //     musicPlayer?.volume = musicVolume
        //     musicPlayer?.play()
        // } catch {
        //     print("Could not load music: \(error)")
        // }
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
    }

    func pauseBackgroundMusic() {
        musicPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        guard isMusicEnabled else { return }
        musicPlayer?.play()
    }

    func setMusicVolume(_ volume: Float) {
        musicVolume = volume
        musicPlayer?.volume = volume
    }

    // MARK: - Sound Effects

    func playSFX(_ sfx: SFX, on node: SKNode) {
        guard isSFXEnabled else { return }

        // Create haptic feedback for important sounds
        switch sfx {
        case .playerHit, .playerDie, .explosion, .critHit:
            triggerHaptic(style: .heavy)
        case .enemyHit, .enemyDie, .dash:
            triggerHaptic(style: .medium)
        case .playerShoot, .buttonPress, .heal:
            triggerHaptic(style: .light)
        default:
            break
        }

        // Play actual sound if we have audio files
        // For now, this is a placeholder that would play real sounds
        // if let action = soundEffects[sfx.rawValue] {
        //     node.run(action)
        // }
    }

    func setSFXVolume(_ volume: Float) {
        sfxVolume = volume
    }

    // MARK: - Haptic Feedback

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func triggerSuccessHaptic() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func triggerWarningHaptic() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func triggerErrorHaptic() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Toggle Settings

    func toggleMusic() {
        isMusicEnabled = !isMusicEnabled
        if isMusicEnabled {
            resumeBackgroundMusic()
        } else {
            pauseBackgroundMusic()
        }
        saveSettings()
    }

    func toggleSFX() {
        isSFXEnabled = !isSFXEnabled
        saveSettings()
    }

    var musicEnabled: Bool {
        get { isMusicEnabled }
        set {
            isMusicEnabled = newValue
            saveSettings()
        }
    }

    var sfxEnabled: Bool {
        get { isSFXEnabled }
        set {
            isSFXEnabled = newValue
            saveSettings()
        }
    }

    var hapticsEnabled: Bool {
        get { isHapticsEnabled }
        set {
            isHapticsEnabled = newValue
            saveSettings()
        }
    }
}
