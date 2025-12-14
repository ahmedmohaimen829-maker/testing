# Slash Ability System - Refactored & Optimized

A production-ready, secure, and optimized slash ability system for Roblox with smooth VFX, audio, ragdolls, and hit detection.

## 🎯 Features

### ✅ Security & Anti-Exploit
- Server-side validation for all ability events
- Cooldown system with server enforcement
- Anti-spam protection (minimum time between hits)
- Character ownership verification
- Max hits per ability validation
- Ability duration timeout protection

### ⚡ Performance Optimizations
- Modular architecture with reusable components
- Optimized VFX emission with burst spreading for large particle counts
- Audio preloading using ContentProvider
- Efficient hitbox detection with proper cleanup
- Memory-efficient VFX cleanup with Debris service
- Minimal heartbeat usage

### 🎨 Visual Enhancements
- Smooth highlight flickering with TweenService
- Improved VFX emission timing
- Better particle emitter handling
- Clean visual feedback for hits
- Debug visualization option for hitboxes

### 🎮 Gameplay Features
- 5-hit combo system with unique VFX per hit
- Movement locking during ability
- Pushback on normal hits
- Ragdoll + knockback on final hit
- Damage system (5 damage per hit)
- Smooth recovery from ragdoll
- 3-second cooldown between uses

## 📁 File Structure

```
ReplicatedStorage/
├── Config.lua              # All configuration settings
├── VFXHandler.lua          # VFX & audio management
└── HitFeedback.lua         # Hit visual feedback

StarterPlayer/StarterCharacterScripts/
└── AbilityClient.lua       # Client-side ability controller

ServerScriptService/
└── AbilityServer.lua       # Server-side validation & hitbox
```

## 🚀 Installation

### Step 1: ReplicatedStorage Setup
1. Create a folder called `RE` in ReplicatedStorage
2. Create a `RemoteEvent` named `SlashAbilityEvent` inside the `RE` folder
3. Place these files in **ReplicatedStorage**:
   - `Config.lua`
   - `VFXHandler.lua`
   - `HitFeedback.lua`

### Step 2: VFX Setup
1. Create the following structure in ReplicatedStorage:
   ```
   ReplicatedStorage/
   └── VFX/
       └── Ability/
           ├── Stab
           ├── Slash1
           ├── Slash3
           ├── Slash4
           └── Final
   ```
2. Each VFX folder should contain your particle emitters, attachments, or parts
3. Add `EmitCount` attribute to ParticleEmitters to control emission amount

### Step 3: Client Setup
1. Place `AbilityClient.lua` in:
   ```
   StarterPlayer > StarterCharacterScripts
   ```

### Step 4: Server Setup
1. Place `AbilityServer.lua` in:
   ```
   ServerScriptService
   ```

### Step 5: Animation Setup
1. Upload your animation to Roblox
2. Open `Config.lua`
3. Update `Config.Animation.ID` with your animation ID
4. Ensure your animation has these markers:
   - `Slash1` (first hit - stab)
   - `Slash2` (second hit - slash)
   - `Slash3` (third hit - slash)
   - `Slash4` (fourth hit - slash)
   - `Final` (fifth hit - final blow)

### Step 6: Audio Setup (Optional)
1. Open `Config.lua`
2. Update audio IDs in `Config.VFX.Effects` for each hit type
3. Adjust `Config.Audio.Volume` if needed

## ⚙️ Configuration

All settings are in `Config.lua`. Key configurations:

### Combat Settings
```lua
Config.Combat = {
    DamagePerHit = 5,              -- Damage per hit
    PushbackForce = 35,            -- Normal hit pushback strength
    KnockbackUpVelocity = 100,     -- Final hit upward force
    KnockbackBackVelocity = 120,   -- Final hit backward force
    RagdollDuration = 2,           -- Ragdoll duration (seconds)
}
```

### Cooldown
```lua
Config.Cooldown = {
    Duration = 3,  -- Seconds between ability uses
}
```

### Hitbox
```lua
Config.Hitbox = {
    Size = Vector3.new(6, 6, 6),
    ForwardOffset = 3.2,
    Duration = 0.5,
    DebugVisualization = false,  -- Set true to see hitboxes
}
```

### VFX Positions & Rotations
```lua
Config.VFX.Effects = {
    Stab = {
        Position = Vector3.new(1, 0, -3),
        Rotation = nil,
    },
    -- ... customize each effect
}
```

## 🎮 Usage

Press **R** to activate the ability (configurable in `Config.Input.ActivationKey`)

## 🔧 Customization

### Adding New VFX
1. Create VFX template in `ReplicatedStorage/VFX/Ability/`
2. Add configuration in `Config.lua` under `Config.VFX.Effects`
3. Add animation marker to your animation
4. Update client script to connect the marker

### Changing Damage/Force Values
- Edit `Config.Combat` in `Config.lua`
- No code changes needed!

### Debug Mode
Set `Config.Hitbox.DebugVisualization = true` to see hitboxes in-game

## 📊 Comparison: Old vs New

| Feature | Old Version | New Version |
|---------|-------------|-------------|
| Security | ❌ No validation | ✅ Full validation |
| Cooldown | ❌ Client-only | ✅ Server-enforced |
| Performance | ⚠️ Heartbeat heavy | ✅ Optimized |
| Code Structure | ❌ Monolithic | ✅ Modular |
| Configuration | ❌ Hardcoded | ✅ Centralized |
| Error Handling | ❌ None | ✅ Full pcall coverage |
| VFX Quality | ⚠️ Basic | ✅ Smooth emission |
| Hit Feedback | ⚠️ Basic | ✅ Smooth tweening |

## 🐛 Troubleshooting

### VFX not showing
- Check that VFX folder structure matches exactly
- Verify `Config.VFX.FolderPath` is correct
- Check console for warnings

### Ability not activating
- Verify animation ID is correct
- Check cooldown (3 seconds between uses)
- Look for errors in server console

### Hitbox not detecting
- Enable debug visualization: `Config.Hitbox.DebugVisualization = true`
- Adjust `Config.Hitbox.Size` or `ForwardOffset`
- Check server console for validation errors

## 📝 Notes

- All validation happens server-side for security
- VFX plays locally first, then replicates to others
- Ragdoll automatically recovers after duration
- Cooldown prevents spam and exploits
- Configuration is shared between client and server

## 🎉 Credits

Refactored and optimized by Claude Code for production use.
