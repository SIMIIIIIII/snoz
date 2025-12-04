# SNOZ - Multi-Agent Snake Game

A concurrent multi-agent snake game implemented in Mozart/Oz for the LINFO1131 Advanced Programming Language Concepts course.

## 📋 Description

SNOZ is a competitive snake game where multiple AI-controlled snakes compete on a randomly generated map. The game features:
- **Multi-agent system** with up to 5 concurrent snake bots
- **Random map generation** with walls and obstacles
- **Regular fruits** that increase snake length
- **Rotten fruits** that shrink snakes by half
- **Invincibility power-ups** for temporary collision immunity
- **Real-time graphics** using Mozart/Oz's graphical interface

## 🎮 Game Features

### Core Mechanics
- **Concurrent agents**: Each snake runs as an independent concurrent agent
- **Message passing**: Communication between game controller and agents via ports
- **Collision detection**: Snakes die when hitting walls, other snakes, or themselves (unless invincible)
- **Dynamic scoring**: Points awarded for eating fruits and surviving

### Special Items
- **🍎 Regular Fruit**: Increases snake length by 1 segment
- **🍏 Rotten Fruit**: Reduces snake length by half (minimum 1 segment)
- **⭐ Invincibility Power-up**: 5-second immunity to all collisions

### Map Generation
- Random wall placement at game start
- Configurable map dimensions
- Strategic obstacle distribution

## 🏗️ Architecture

### Main Components

```
Main.oz           - Game controller and main loop
AgentManager.oz   - Bot lifecycle management
AgentBlank.oz     - AI agent implementation (random movement strategy)
Graphics.oz       - Display rendering and snake visualization
Input.oz          - Game configuration and parameters
```

### Message Protocol
The game uses a message-passing architecture where:
- Game controller broadcasts game state updates
- Agents send direction commands
- Asynchronous communication via ports

## 🚀 Getting Started

### Prerequisites
- **Mozart 2** programming system installed
- macOS or Linux environment

### Installation

1. Clone or download the project:
```bash
cd snoz
```

2. Compile the project:
```bash
make compile
```

3. Run the game:
```bash
make run
```

Or compile and run in one command:
```bash
make
```

### Configuration

Edit `Input.oz` to customize:
- Number of bots (1-5)
- Map dimensions
- Initial snake positions
- Game speed and timing parameters

## 📂 Project Structure

```
snoz/
├── Main.oz                    # Game controller
├── AgentManager.oz            # Bot management
├── AgentBlank.oz             # AI agent implementation
├── Graphics.oz               # Rendering engine
├── Input.oz                  # Configuration
├── Makefile                  # Build system
├── README.md                 # This file
├── rotten_fruit_implementation.txt  # Feature documentation
├── assets/                   # Graphics assets
│   ├── ground/              # Background sprites
│   ├── SNAKE_1/ to SNAKE_5/ # Snake sprites
├── compiled/                 # Compiled .ozf files
└── rapport/                  # Project report (French)
    ├── rapport.tex
    ├── rapport.pdf
    └── ...
```

## 🎯 Implementation Highlights

### Rotten Fruit System
- Shrinks snake to 50% of current length
- Immediate visual update (tail segments disappear)
- Maintains minimum length of 1 (head)
- Implemented via `shrink()` method in Graphics.oz

### Power-up System
- 5-second invincibility duration
- Visual feedback (color change)
- Timed deactivation via thread
- Collision immunity without affecting movement

### Collision Detection
- Wall collisions
- Self-collisions (snake hitting its own body)
- Inter-snake collisions
- Fruit collection detection

## 🧪 Testing

The game has been tested with:
- Multiple concurrent agents (1-5 bots)
- Various map configurations
- Edge cases (minimum snake length, simultaneous collisions)
- Power-up timing and stacking

## 📝 Documentation

Detailed technical documentation available in:
- `rotten_fruit_implementation.txt` - Feature implementation details
- `rapport/rapport.pdf` - Full project report (French)

## 🎓 Academic Context

**Course**: LINFO1131 - Advanced Programming Language Concepts  
**Institution**: Université catholique de Louvain (UCLouvain)  
**Year**: 2025  
**Language**: Mozart/Oz

## 👥 Authors

See `Makefile` for group number and student information.

## 📄 License

Academic project - UCLouvain SINF1BA

---

**Note**: This is an academic project developed for educational purposes in concurrent and functional programming.