<p align="center">
  <img src="assets/shatterpulse-logo.jpg" alt="ShatterPulse" width="360">
</p>

# ShatterPulse

**Blizzard-style Frozen, Shatter and Fingers of Frost proc alerts for Frost Mages in WoW Forever.**

Created by **Schrubber**.

[CurseForge page](https://www.curseforge.com/wow/addons/shatterpulse)

## What it does

ShatterPulse gives Frost Mages a clear visual and audio cue when a Shatter opportunity is available.

- **Frozen target:** two frost arcs appear to the left and right of your character.
- **Fingers of Frost:** a separate frost crown appears above your character.
- **Both active:** all three indicators can appear together.
- **Exact freeze state:** the Frozen overlay disappears with the actual freeze aura rather than using a guessed Frost Nova timer.
- **Optional sounds:** five bundled frost-themed proc sounds can be used for Freeze and/or Fingers of Frost.

## Visual styles

- Retail Split Overlay *(recommended)*
- Split + Ice Lance
- Clean Ice Lance
- Ice Lance + Glow

You can adjust overlay scale, side spacing, FoF height, opacity, glow intensity, flash speed and flash strength from the in-game menu.

## Sounds

ShatterPulse includes five bundled sounds:

- Crystal
- Ice Crack
- Frost Chime
- Sharp Ping
- Frost Whoosh

The selected sound can trigger on hard-freeze auras and optionally on Fingers of Frost.

## Installation

### CurseForge

The easiest option is the [ShatterPulse CurseForge page](https://www.curseforge.com/wow/addons/shatterpulse).

### Manual install

1. Download a release ZIP from GitHub.
2. Extract it.
3. Copy the `ShatterPulse` folder to:

```text
World of Warcraft/_classic_beta_/Interface/AddOns/
```

4. Reload or restart WoW Forever.

If you used an early development build, remove the old `IceLanceHelper` folder first.

## Commands

```text
/sp menu
/sp test frozen
/sp test fof
/sp test both
/sp test off
/sp move
/sp lock
/sp sound crystal
/sp sound crack
/sp sound chime
/sp sound ping
/sp sound whoosh
/sp soundtest
/sp freezesound
/sp fofsound
/sp style split
/sp style clean
/sp style blizzard
/sp style combo
/sp overlay 1.0
/sp size 82
/sp alpha 0.9
/sp flash 1.2
/sp strength 1.4
/sp glow 1.5
/sp status
```

`/shatterpulse` can be used instead of `/sp`.

## WoW Forever compatibility

WoW Forever restricts some combat and enemy-aura information. ShatterPulse uses Blizzard-safe proc events and AuraContainer tracking rather than restricted combat-log tricks.

The addon currently targets **Interface 16001**.

Because WoW Forever is still changing, spell IDs or API behavior may change between builds. If something breaks, please open a GitHub issue and include:

- ShatterPulse version
- WoW Forever build
- which proc did not work
- any Lua error shown by the client

## Development

The Lua source lives in the `ShatterPulse/` folder. To keep the repository compact, bundled binary media is stored as `media-src/Media.zip`.

Before testing a clone locally, run:

```bash
./scripts/prepare-media.sh
```

This extracts the required textures and sounds into `ShatterPulse/Media/`.

Creating a Git tag such as `v1.0.1` triggers the included GitHub Actions workflow. The workflow prepares the media automatically, builds an installable `ShatterPulse-1.0.1.zip`, and publishes it as a GitHub Release.

## Credits

**Created by Schrubber**  
Built for the WoW Forever Frost Mage community.

ShatterPulse is an independent community addon and is not affiliated with or endorsed by Blizzard Entertainment.

## License

Copyright © 2026 Schrubber. All rights reserved. See [LICENSE](LICENSE).
