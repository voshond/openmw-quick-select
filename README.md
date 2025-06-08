# voshond's Quickselect

### Requirements

OpenMW build(0.49+) required

### Description

This mod is basically a fork of ZackHasaCat's [Quickselect](https://gitlab.com/modding-openmw/quickselect/) OpenMW mod, but modified based on my personal needs from a PC player's perspective.

#### A quick summary of the features

- Adds up to 3 Hotbars to the game
- Allows the player to bind items, spells and enchantments to the hotbars
- Gives the player direct access to these by pressing 1-0, shift 1-0 or ctrl 1-0
- Allows for customisation of the icon size, spacing between and the number of bars shown

#### Noteable modifications from the original

- Managing bars does not "switch" the bar, but instead the player can directly access the bar by using shift/ctrl - this is probably the most noteable diviation, as it seems quickselect was more built with an controller in mind (i don't really do that)
- Activating a weapon/spell that is already equipped will simply "unready" that weapon/spell
- If you do not have the spell/weapon equipped, the player simply readies the activated spell
- If the user has a spell ready, and simply switches to another spell, the stance is maintained
- Same goes when switchting to a torch/probe/lockpick

### Original Notes

**Before installing this mod, you should unbind all the vanilla hotkeys!**

Quickselect adds a hotbar to the UI, with custom behaviour.

You can either have it show at all times, or only show when needed. It allows for a more controller friendly experience, the shoulder buttons/dpad left/right allow you to select which slot to use, then A to use it.

The mod re-implements the vanilla favorite menu(F1), with some enhancements.

If you press a hotkey which has an item equipped already, it will unequip it.

You can have 3 hotbars. Press Shift+1, or use the DPad up and down buttons to choose your hotbar. You can also use the -/= keys or the [/] keys, but you must unbind them from their default purpose.

You can use the DPad/Shoulder buttons to select which item you'd like to equip. If enabled, you can also use the arrow keys for this.

Check the settings, you can customize behaviour from there.

### Credits

Author: voshond
Original Author of QuickSelect: ZackHasaCat

### Installation

1.  Download the mod from the above link, release or dev version.
1.  Extract the zip to a location of your choosing, examples below:

        # Windows
        C:\games\OpenMWMods\quickselect

        # Linux
        /home/username/games/OpenMWMods/quickselect

        # macOS
        /Users/username/games/OpenMWMods/quickselect

1.  Add the appropriate data path to your `opemw.cfg` file (e.g. `data="C:\games\OpenMWMods\quickselect"`)
1.  Add `content=quickselect.omwscripts` to your load order in `openmw.cfg` or enable it via OpenMW-Launcher

### Report A Problem

If you've found an issue with this mod, or if you simply have a question, please use one of the following ways to reach out:

- [Open an issue on Github](https://github.com/voshond/openmw-quick-select/issues)

### For Developers

#### Development Scripts

All development scripts are now organized in the `dev-scripts/` directory and can be accessed through proxy scripts in the root:

**Linux/macOS:**

```bash
./dev.sh <command> [options]
```

**Windows:**

```powershell
.\dev.ps1 <command> [options]
```

Available commands:

- `debug` - Debug the mod (copy files and restart OpenMW)
- `deploy` - Deploy a new version (create tag and release)
- `package` - Package the mod for distribution

#### Examples

```bash
# Debug the mod with focus on existing OpenMW window
./dev.sh debug -focus

# Deploy a new version
./dev.sh deploy -v 1.2.3 -m "Bug fixes and improvements"

# Package the mod
./dev.sh package -v 1.2.3
```

#### Deployment

To create a new release:

1. Make sure all your changes are committed
2. Run the deployment script: `./dev.sh deploy` (Linux/macOS) or `.\dev.ps1 deploy` (Windows)
3. Enter the version number when prompted (format: x.y.z)
4. Enter release notes when prompted (optional)
5. The script will:
   - Update the CHANGELOG.md
   - Package the mod
   - Create a Git tag
   - Push changes to GitHub
   - Trigger the GitHub Actions workflow to create a release

You can also run the script with parameters: `./dev.sh deploy -v "1.2.3" -m "Release notes here"`
