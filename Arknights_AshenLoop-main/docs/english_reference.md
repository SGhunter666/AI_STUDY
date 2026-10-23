# Ashen Circuit English Reference

This document is the English-language reference for the game's localization, systems, and player-facing terminology. The default in-game experience is Simplified Chinese, while English can be selected from Settings.

## Localization Policy

- Simplified Chinese is the default player-facing language.
- The Settings menu exposes Video, Language, Gameplay, and Audio sections.
- Card names, card descriptions, card tags, tooltips, combat logs, encyclopedia entries, event text, shop text, rest-site text, and reward text should be routed through localized strings or already-localized resource fields.
- Internal identifiers, script fields, filenames, effect operation names, and data tags may remain English for stability.
- English localization must never leak into Simplified Chinese mode.

## Core Combat Terms

Energy: The turn resource spent to play cards.
Health: The unit's life total.
Block: Temporary protection that absorbs incoming damage.
Will: Amiya's build-up resource for stronger Arts turns.
Resonance: A stackable setup resource placed on units.
Echo: A temporary modifier that repeats part of a later card effect.
Channel: A delayed-effect card mechanic.
Overload: A risk resource that can hurt the player but unlocks payoff cards.
Support: A sequencing tag for command and assistance cards.
Arts: Spell-like damage and tactical effects.
Weak: Reduces outgoing damage.
Vulnerable: Increases incoming damage.
Slow: Reduces or delays enemy pressure.
Exhaust: Removes a card from combat after use.
Ethereal: Removes a card if it remains in hand at turn end.
Multi-hit: A card or action that hits multiple times.
Area damage: An effect that hits all enemies.

## Exusiai Terms

Ammo: Exusiai's ammunition resource.
Shot: Exusiai's main attack tag.
Reload: Restores or manages ammunition.
Mark: A target setup resource for follow-up fire.
Burst: Exusiai's next-turn empowered volley window.
Tempo: Draw, cost, and resource flow.
Finisher: A payoff card meant to close a fight or kill a priority target.

## Kal'tsit Terms

Mon3tr: Kal'tsit's persistent summon.
Integrity: Mon3tr's structural value.
Repair: Restores Integrity.
Medical: Healing, repair, and sustain cards.
Protocol: Long-term engine cards.
Command: Orders that direct Mon3tr or shape the battle.
Meltdown: Mon3tr's high-power state at maximum Integrity.
Scalpel: Kal'tsit's personal attack category.

## Settings Sections

Video Settings: Resolution, display mode, fullscreen, borderless window, vertical sync, and UI scale.
Language Settings: Switches between Simplified Chinese and English.
Gameplay Settings: Automation, confirmation, and combat-flow options.
Audio Settings: Master, music, sound effect, voice, warning, special, UI, and combat volume groups.
