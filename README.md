# Balatro Hand Preview

<div align="center">

![GitHub license](https://img.shields.io/github/license/hxll-f/HandPreview)

**A fork of [Toeler/Balatro-HandPreview](https://github.com/Toeler/Balatro-HandPreview).**

</div>

<p align="center">
  <img src="https://i.imgur.com/9xWUIDX.png" alt="Balatro Hand Preview Logo">
</p>

> [!NOTE]
> This is a modified version of Toeler's Hand Preview mod, not the original. It
> does the same thing and looks the same; the hand analysis behind it has been
> rewritten so that it no longer costs framerate. See
> [What's different in this fork](#-whats-different-in-this-fork).
> All credit for the mod itself goes to [Toeler](https://github.com/Toeler).

## 📜 Description

Hand Preview is a mod for Balatro that adds a window showing the possible poker hands that you can make with your current hand!

## ✨ Features

<p align="center">
  <img src="https://i.imgur.com/8dkkvna.png" alt="Hand Preview Window" width="400">
</p>

- Displays a window with possible poker hands you can create with your current cards.

<p align="center">
  <img src="https://i.imgur.com/lW3Ooai.gif" alt="Moving the Hand Preview Window" width="400">
</p>

- Move the window wherever you want!
- Change the anchor point to keep it from overlapping other things on the screen.

<p align="center">
  <img src="https://i.imgur.com/LYQ8nNn.png" alt="Settings Window" width="400">
</p>

- Change the number of hands shown.
- Include or exclude face-down cards in the possible hand calculation (default: Exclude).
- Include or exclude a list of the cards that will make up a possible hand (default: Exclude).

## ⚡ What's different in this fork

### Performance

The original worked out the possible hands by brute force: it built every
selection of one to five cards from your hand and asked the game to score each
one. That is 218 evaluations for an eight card hand, and 4,943 for fourteen. It
ran whenever the hand changed, which during the deal meant once per card that
landed, and under Steamodded each of those evaluations also fired a full joker
calculation pass.

This fork works the candidate selections out directly from the hand's structure
— rank groups, straight runs, per-suit flush candidates — and only asks the game
to score those. It also waits for the deal to finish instead of recalculating on
every card.

| | before | after |
| --- | --- | --- |
| 8 card hand | 1.8 ms, once per card dealt | 0.21 ms, once |
| 10 card hand | 5.1 ms | 0.22 ms |
| 12 card hand | 12.9 ms | 0.31 ms |
| 14 card hand | 28.5 ms | 0.39 ms |
| per-frame change check | 1.66 µs, allocates | 0.11 µs, allocation free |

A typical hand now needs about 7 evaluations rather than a few hundred to a few
thousand. Alongside that:

- The preview waits for the hand to settle — dealing, tarots, boss blinds,
  jokers destroying cards — and refreshes once, rather than part way through.
- Dragging the window no longer writes the settings file on every frame.
- The rows are rebuilt in a single UI pass, and only when the text has actually
  changed.
- The preview window is no longer left behind and updated forever when a new run
  starts.

### Fixes

- **Five of a Kind, Flush House and Flush Five now appear.** The original had no
  description text for them, and silently dropped any hand type it could not
  describe.
- **Rows and their breakdown text sort deterministically**, instead of shuffling
  around between refreshes.
- The hand evaluation no longer fires Steamodded's `evaluate_poker_hand` joker
  context, which was never meant to run hundreds of times for a preview.

### Accuracy

The rewrite was checked against the original algorithm over 45,600 randomly
generated hands — 8, 10 and 14 card hands, pair heavy, straight heavy, flush
heavy, face-down cards, Stone and Wild Cards, forced-selection boss blinds, and
every combination of Four Fingers, Shortcut and Smeared Joker:

- With the default settings, the listed hands match the original **exactly**.
- With "Include Hand Breakdown" turned on, 6 hands out of 45,600 (0.013%) are
  missing one extra `X-Y` range inside a Straight or Straight Flush row that is
  itself still listed, and only while one of those three jokers is equipped.

## 📦 Installation Instructions

### Prerequisites

- Ensure you have [Steamodded](https://github.com/Steamopollys/Steamodded) installed for managing Balatro mods.

### Steps

1. **Download the Mod**:

   - Clone this repository, or download it as a ZIP from GitHub.
   - For the original, unmodified mod, use the
     [upstream releases page](https://github.com/Toeler/Balatro-HandPreview/releases) instead.

2. **Install the Mod**:

   - Copy this repository's `Mods` folder into your Balatro data folder:
     - **Windows**: `C:\Users\<USER>\AppData\Roaming\Balatro\Mods` (or `%appdata%\Balatro\Mods`)
     - **Mac/Linux**: `/home/$USER/.local/share/Steam/steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods`
   - It contains both Hand Preview and BalaLib, which it depends on.

3. **Restart Balatro**:
   - Restart the game to apply the changes.

## 📄 License

This project is licensed under the GPL-3.0 License, the same as the original. See the [LICENSE](LICENSE) file for details.

## 📬 Contact

For issues with this fork, please open an issue here. For the original mod,
please use [Toeler's repository](https://github.com/Toeler/Balatro-HandPreview/issues).

## 🤝 Contributing

Contributions are welcome! If you would like to contribute, please fork the repository and use a feature branch. Pull requests are warmly welcome.

---
