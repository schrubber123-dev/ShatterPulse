# ShatterPulse

[![CurseForge](https://img.shields.io/badge/CurseForge-Download-F16436?logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/shatterpulse)
![WoW Forever](https://img.shields.io/badge/WoW-Forever-4A90E2)
![Version](https://img.shields.io/badge/version-1.0.0-7ACBFF)

**Blizzard-style Frozen, Shatter and Fingers of Frost proc alerts for Frost Mages in WoW Forever.**

Created by **Schrubber**.

## Download

The official installable build, including the bundled frost textures and sounds, is available on CurseForge:

**https://www.curseforge.com/wow/addons/shatterpulse**

> The GitHub repository is the development/source repository. Use the CurseForge package for normal installation because the binary artwork and audio files are distributed with the packaged addon.

## Features

- **Frozen target indicator** — frost arcs appear to the left and right of your character.
- **Fingers of Frost indicator** — a separate frost crown appears above your character.
- **Combined state** — both indicators can be visible at the same time.
- **Aura-driven Frozen state** — the overlay disappears when the actual freeze aura disappears; no guessed Frost Nova timer.
- **Five frost-themed proc sounds** — Crystal, Ice Crack, Frost Chime, Sharp Ping and Frost Whoosh.
- **Separate sound toggles** for Freeze and Fingers of Frost.
- **Adjustable visuals** — scale, spacing, FoF height, opacity, glow intensity, flash speed and flash strength.
- **Optional Ice Lance icon modes.**
- **Minimap configuration button.**
- **Preview modes** for Frozen, FoF and Both.
- **Blizzard-style settings window** with General, Visuals, Sounds, Preview and FAQ / About pages.

## Visual styles

- **Retail Split Overlay** *(recommended)*
- **Split + Ice Lance**
- **Clean Ice Lance**
- **Ice Lance + Glow**

### Proc logic

| State | Display |
| --- | --- |
| Target Frozen | Left + right frost arcs |
| Fingers of Frost | Frost crown above character |
| Both | Side arcs + top crown |

## Sounds

The packaged addon contains five selectable sounds:

- Crystal
- Ice Crack
- Frost Chime
- Sharp Ping
- Frost Whoosh

The selected sound can trigger on a hard freeze and optionally on Fingers of Frost.

## Installation

For players, install the current release from the [CurseForge project page](https://www.curseforge.com/wow/addons/shatterpulse).

If you used one of the early development versions, remove the old `IceLanceHelper` folder before installing ShatterPulse.

The addon folder belongs in:

```text
World of Warcraft/_classic_beta_/Interface/AddOns/ShatterPulse/
```

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

You can use `/shatterpulse` instead of `/sp`.

## WoW Forever compatibility

ShatterPulse was built specifically for **WoW Forever** and currently targets **Interface 16001**.

WoW Forever restricts some enemy-aura and combat information. ShatterPulse therefore uses Blizzard-safe proc events and AuraContainer tracking rather than restricted combat-log workarounds.

Because Forever is still evolving, spell IDs and API behavior can change between builds. If something stops working after an update, please open a bug report and include:

- ShatterPulse version
- WoW Forever build
- which proc did not work
- any Lua error shown by the client

## Repository structure

```text
ShatterPulse/
├── ShatterPulse.lua
├── ShatterPulse.toc
├── README.txt
└── CHANGELOG.txt

.github/
└── ISSUE_TEMPLATE/

README.md
CHANGELOG.md
LICENSE
```

The source repository intentionally does not include the packaged binary frost textures and audio files. Those are included in the official CurseForge download.

## Feedback

Use GitHub Issues for bug reports, Forever compatibility problems, feature requests, proc-detection problems and UI suggestions.

## Credits

**Created by Schrubber**

Built for the WoW Forever Frost Mage community.

ShatterPulse is an independent community addon and is not affiliated with or endorsed by Blizzard Entertainment.

## License

Copyright © 2026 Schrubber. All rights reserved. See [LICENSE](LICENSE).
