# RogueWave - iOS Roguelike Wave Survival Game

A real-time top-down roguelike wave survival game for iPhone built with SpriteKit and Swift.

## Features

### Core Gameplay
- **Smooth Movement**: Virtual joystick control for fluid 8-directional movement
- **Auto-Attacks**: Automatic targeting and shooting at nearest enemies
- **Endless Waves**: Progressively harder waves with scaling difficulty
- **Boss Fights**: Boss encounters every 5 waves
- **Upgrades**: Choose from 3 random upgrades after each wave

### Player System
- Health, speed, damage, and attack speed stats
- Critical hit chance and multiplier
- Experience and leveling system
- Hit feedback with flash and shake effects
- Invincibility frames after taking damage

### Enemy Types
1. **Chaser** - Basic enemy that moves toward player
2. **Swarm** - Fast, weak enemies that attack in groups
3. **Ranged** - Keeps distance and shoots projectiles
4. **Tank** - Slow but high health and damage
5. **Elite** - Enhanced version of any type (3x health, 1.5x damage)
6. **Boss** - Massive enemies with 10x health

### Wave System
- Time-based waves (30 seconds each)
- Scaling difficulty with each wave
- Wave modifiers (speed boost, health boost, swarm, etc.)
- Predefined first 3 waves for balanced early game

### Upgrade Types

**Passive Upgrades:**
- Max Health (+20 HP)
- Move Speed (+10%)
- Damage (+5)
- Attack Speed (+15%)
- Critical Chance (+5%)
- Critical Damage (+25%)
- Attack Range (+30)
- Projectile Speed (+50)
- Armor (+5)
- Life Steal (+3%)

**Active Abilities:**
- Dash - Quick invincible dash
- AOE Blast - Area damage around player
- Shield - Temporary damage immunity
- Multishot - Additional projectiles
- Piercing - Projectiles pass through enemies
- Homing - Projectiles track enemies

### Build Synergies
- **Glass Cannon**: Damage + Crit Chance + Crit Damage = +30% damage
- **Speedster**: Speed + Attack Speed + Dash = +20% speed, +15% cooldown reduction
- **Tank**: Health + Armor + Shield = +25% health
- **Gunslinger**: Multishot + Projectile Speed + Attack Speed = +10% crit chance
- **Vampire**: Life Steal + Damage + Attack Speed = +15% damage, +10% health

### Meta-Progression
- Earn gold from kills and wave completion
- Purchase permanent upgrades between runs
- Track achievements and high scores
- Persistent save data using UserDefaults

## Project Structure

```
RogueWave/
├── RogueWave.xcodeproj/
│   └── project.pbxproj
└── RogueWave/
    ├── Core/
    │   ├── GameScene.swift          # Main game loop and scene management
    │   └── Constants.swift          # Game configuration and constants
    ├── Entities/
    │   ├── Player.swift             # Player class with stats and abilities
    │   ├── Enemy.swift              # Enemy types and behaviors
    │   └── Projectile.swift         # Projectile system
    ├── Systems/
    │   ├── WaveManager.swift        # Wave spawning and progression
    │   ├── UpgradeSystem.swift      # Upgrade management and synergies
    │   └── GameManager.swift        # Persistence and meta-progression
    ├── UI/
    │   ├── VirtualJoystick.swift    # Touch input for movement
    │   └── UIManager.swift          # HUD and overlay screens
    ├── Utils/
    │   └── ObjectPool.swift         # Object pooling for performance
    ├── AppDelegate.swift
    ├── GameViewController.swift
    ├── Assets.xcassets/
    ├── LaunchScreen.storyboard
    └── Info.plist
```

## How to Open and Run in Xcode

### Prerequisites
- macOS with Xcode 15.0 or later
- iOS 15.0+ deployment target
- iPhone or iOS Simulator

### Steps

1. **Open the Project**
   ```bash
   cd RogueWave
   open RogueWave.xcodeproj
   ```

2. **Select Target Device**
   - Choose an iPhone simulator or connected device from the scheme dropdown

3. **Build and Run**
   - Press `Cmd + R` or click the Play button
   - Wait for the build to complete

4. **Play the Game**
   - Use the left side of the screen to move (virtual joystick)
   - Auto-attacks target nearest enemy
   - Tap right side of screen to use abilities
   - Survive waves and collect upgrades!

## Controls

| Input | Action |
|-------|--------|
| Touch & drag left side | Move player |
| Tap right side | Use ability (Dash/AOE/Shield) |
| Tap pause button (top right) | Pause game |

## Game Flow

1. **Start** - Game begins at Wave 1
2. **Survive** - Fight enemies for 30 seconds per wave
3. **Upgrade** - Choose 1 of 3 upgrades after wave completion
4. **Progress** - Face harder waves with more enemies
5. **Boss** - Every 5th wave features a boss
6. **Death** - View stats and earn gold for meta-progression
7. **Repeat** - Start new run with permanent bonuses

## Performance Optimizations

- **Object Pooling**: Reuses enemy and projectile instances
- **Minimal Physics**: Simple collision detection without complex physics
- **Efficient Rendering**: Shape nodes with proper z-ordering
- **60 FPS Target**: Optimized update loop

## Customization

### Adjusting Difficulty
Edit values in `Constants.swift`:
- `WaveConfig.waveDuration` - Wave length
- `WaveConfig.baseEnemyCount` - Starting enemy count
- `EnemyConfig.healthScalingPerWave` - Health increase per wave
- `PlayerConfig.baseHealth` - Starting player health

### Adding New Enemy Types
1. Add new case to `EnemyType` enum
2. Create configuration in `EnemyConfig`
3. Implement behavior in `Enemy.swift`
4. Add to wave spawn tables in `WaveConfig`

### Adding New Upgrades
1. Add new case to `UpgradeType` enum
2. Set properties (name, description, color)
3. Implement effect in `Player.applyUpgrade()`
4. Add to upgrade pool in `UpgradePoolConfig`

## Technical Details

- **Language**: Swift 5
- **Framework**: SpriteKit
- **Architecture**: Component-based with delegate patterns
- **Persistence**: UserDefaults with Codable structs
- **Minimum iOS**: 15.0

## Future Improvements

- [ ] Sound effects and music
- [ ] More enemy types
- [ ] Additional weapons/characters
- [ ] Game Center leaderboards
- [ ] iCloud save sync
- [ ] Haptic feedback
- [ ] Particle effects system

## License

This project is provided as-is for educational purposes.

---

Built with SpriteKit for iOS
