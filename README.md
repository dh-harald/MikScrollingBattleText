![GitHub Release](https://img.shields.io/github/v/release/dh-harald/MikScrollingBattleText) ![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/dh-harald/MikScrollingBattleText/package.yaml) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/dh-harald/MikScrollingBattleText/total)
# Mik's Scrolling Battle Text for 1.12.1 and Unreal Azeroth

A port of **Mik's Scrolling Battle Text** (MSBT) 6.0 by Mikord to the WoW 1.12.1
client (Lua 5.0) and to **Unreal Azeroth**, the Unreal Engine reimplementation of
the 1.12.1 client (Lua 5.1). One addon runs on both.

The 1.12.1 client has no structured combat log, so every event is parsed from
the combat log chat lines. The parser builds its patterns from the client's own
localized combat strings, so it works on every client language.

## Features

- Scroll areas: the four default areas (Incoming, Outgoing, Notification,
  Static) plus any number of custom areas.
- Animation styles: Straight, Parabola, Angled, Horizontal and Static, and the
  sticky styles Pow and Static. Crits can be shown sticky.
- About 150 event types:
  - incoming and outgoing melee, skill, damage over time and damage shield hits,
    all miss types, heals and heals over time, for both the player and the pet;
  - environmental damage, interrupts and dispels;
  - buffs, debuffs and item buffs, with stacks and fades;
  - power gains and losses, combo points, entering and leaving combat;
  - honor, reputation, skill ups, experience and killing blows;
  - extra attacks, enemy buffs, monster emotes, loot and money;
  - skill, pet and item cooldowns.
- Per-event settings: message template, color, scroll area, sticky, sound and
  font overrides.
- Display details:
  - partial effects (absorb, block, resist, vulnerability, crushing, glancing)
    and overheal;
  - damage school and class colors;
  - skill icons, from the spellbook, LibBabble-Spell-2.2 and the player's auras.
- Spam control: merging, throttling, thresholds, skill suppressions and
  substitutions, merge exclusions.
- Triggers:
  - uses the classic MSBT trigger format;
  - editor for main events, conditions, exceptions and classes;
  - default triggers: Low Health, Low Mana, Low Pet Health, Execute, Hammer of
    Wrath, Revenge, Overpower, Riposte, Counterattack, Mongoose Bite,
    Clearcasting, Shadow Trance.
- Loot alerts with quality filters and allow/exclude lists.
- Profiles (AceDB-3.0) and custom fonts and sounds (LibSharedMedia-3.0).
- Options window (LibConfig-1.0): `/msbt`.
- Move mode for the scroll areas, with a grid, arrow key nudging and preview:
  `/msbt move`.
- The public MSBT API (`MikSBT.DisplayMessage`, `MikSBT.RegisterFont`,
  `MikSBT.RegisterSound`, `MikSBT.RegisterAnimationStyle`, ...).

## Commands

| Command | |
|---|---|
| `/msbt` | Open the options |
| `/msbt move` | Move the scroll areas |
| `/msbt test` | Show test events |
| `/msbt reset` | Reset the current profile |
| `/msbt enable`, `/msbt disable` | Enable or disable the mod |
| `/msbt version` | Show the version |
| `/msbt search <text>` | Print combat log lines containing the text |
| `/msbt eventlog on/off/clear` | Record combat log lines into the `MSBTDebugLog` saved variable |

## Libraries

LibStub, CallbackHandler-1.0, AceCore-3.0, AceLocale-3.0, AceDB-3.0,
AceDBOptions-3.0, LibSharedMedia-3.0, LibConfig-1.0 and LibBabble-Spell-2.2,
all in their 1.12.1 (Ace3v) versions.

## Languages

English, French, German, Spanish, Russian and Simplified Chinese. The combat log
itself is parsed in the client's language regardless of these files.

## Differences from MSBT 6.0

Everything the 1.12.1 client has is ported. Left out, because the client does
not have them: Chi, Holy Power, Arcane Charges, Essence, alternate power,
currencies, overkill, specializations, the multi-school damage colors and the
classes added after 1.12.

## Known issues

- None yet.

## Credits

Original addon: Mikord (Mik's Scrolling Battle Text). The 1.12.1 combat log
parsing follows the approach of the vanilla MSBT 4.43 port.
