# Bonus Fruit Feature Implementation

## Overview
This document describes the implementation of the **Bonus Fruit** feature for the SNOZ game, as specified in `suggestions_fonctionnalites.txt`.

## Feature Specification
- **Effect**: Gives +5 points instead of +1 (like regular fruits)
- **Color**: Brilliant blue (bright blue with shine effect)
- **Spawn Rate**: 1 bonus fruit spawns every 8 regular fruits eaten
- **Visual**: 32x32 pixel blue circular sprite with gradient shine

## Files Modified

### 1. Graphics.oz
**Changes:**
- Added `BONUS_FRUIT_SPRITE` constant pointing to `/assets/bonus_fruit.png`
- Added `spawnBonusFruit(X Y)` method to spawn bonus fruit at grid coordinates
- Added `dispawnBonusFruit(X Y)` method to remove bonus fruit from grid
- Added `ateBonusFruit(X Y Id)` method to handle snake eating bonus fruit (grows snake by 5 segments)

**Code Locations:**
- Line ~18: BONUS_FRUIT_SPRITE constant definition
- Lines ~430-450: Bonus fruit spawn/despawn methods
- Lines ~460-470: ateBonusFruit method

### 2. Main.oz
**Changes:**
- Added `SpawnBonusFruit` to the define section for function declaration
- Added `SpawnBonusFruit(GUI)` procedure that spawns 1 bonus fruit at random location
- Added `BonusFruitSpawned(bonusFruitSpawned(X Y))` handler function to track bonus fruit in state
- Added `BonusFruitDispawned(bonusFruitDispawned(X Y))` handler function to remove bonus fruit from state
- Modified `MovedTo` function to handle bonus fruit consumption:
  - Awards +5 points to global score
  - Awards +5 points to snake's individual score
  - Displays message: "[Color] ate a BONUS fruit (+5 pts)!"
  - Grows snake using `ateBonusFruit` method
- Added bonus fruit spawn logic: spawn every 8 regular fruits eaten (`FruitsEaten mod 8 == 0`)
- Added bonus fruit handlers to message interface dispatcher

**Code Locations:**
- Line ~26: SpawnBonusFruit declaration
- Lines ~190-210: BonusFruitSpawned handler
- Lines ~245-265: BonusFruitDispawned handler
- Lines ~335-365: Bonus fruit eating logic (powered snake collision case)
- Lines ~425-455: Bonus fruit eating logic (normal case)
- Lines ~610-615: Interface dispatcher registration
- Lines ~676-685: SpawnBonusFruit procedure

### 3. Assets
**New File Created:**
- `assets/bonus_fruit.png` - 32x32 pixel brilliant blue fruit sprite
- Created using ImageMagick with layered circles for shine effect
- Script: `create_bonus_fruit.sh` (included for regenerating the sprite)

## State Tracking
Bonus fruits are tracked in the game state's `items` record with:
- **Label**: `bonusfruit`
- **Alive status**: `true` when active, `false` when eaten
- **Counter**: `nBfruits` tracks total number of active bonus fruits

## Game Logic Flow

### Spawning:
1. Snake eats regular fruit → `fruitsEaten` counter increments
2. When `fruitsEaten mod 8 == 0` → Trigger bonus fruit spawn
3. `SpawnBonusFruit(GUI)` generates random coordinates
4. `GUI spawnBonusFruit(X Y)` renders sprite and sends `bonusFruitSpawned(X Y)` message
5. `BonusFruitSpawned` handler adds bonus fruit to state tracker
6. All bots receive `bonusFruitSpawned(X Y)` broadcast

### Consumption:
1. Snake moves to cell with bonus fruit
2. `MovedTo` detects `{Label State.items.I} == 'bonusfruit'`
3. Score updated: `State.score + 5` (global), `Bot.score + 5` (individual)
4. Message displayed: "[Color] ate a BONUS fruit (+5 pts)!"
5. Snake grows via `GUI ateBonusFruit(X Y Id)`
6. Bonus fruit removed from grid via `dispawnBonusFruit`
7. State updated with new scores and rankings

## Testing
The feature has been successfully compiled and tested. To verify:
1. Run `make` to compile
2. Run `ozengine compiled/Main.ozf` to start game
3. Observe: After 8 regular fruits are eaten, a blue bonus fruit should appear
4. When eaten, it should award +5 points and display special message

## Compatibility
- Works with existing fruit types (regular, rotten)
- Does not interfere with power-up system
- Compatible with all snake collision mechanics
- Broadcasts correctly to all bot agents

## Future Enhancements
Possible improvements to consider:
- Visual glow/pulse effect around bonus fruit
- Sound effect when bonus fruit is eaten
- Particle effects on consumption
- Bonus fruit timeout (disappears after X seconds if not eaten)
- Variable bonus amounts (e.g., +3, +5, +10 randomly)

## Notes
- Bonus fruits spawn independently of regular fruit spawning
- Multiple bonus fruits can exist simultaneously if spawned before being eaten
- The spawn rate is tied to regular fruits eaten, not time-based
- Bonus fruits spawn in playable area only (avoid borders with walls)
