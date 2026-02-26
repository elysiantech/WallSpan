# WallSpan

A macOS menu bar app that downloads high-resolution photos from Unsplash and spans them as wallpaper across single or multi-monitor setups.

## Features

- **Menu bar only** — no dock icon, runs silently in the background
- **Multi-monitor spanning** — detects all connected screens, their arrangement, and resolution, then slices a single image across them as one continuous wallpaper
- **Single monitor** — works normally on a laptop or single-display setup
- **Auto-rotation** — configurable interval (30 min to 24 hours)
- **Themed search** — ships with bridge night photography, nebula/astrophotography, and aerial drone cityscape search terms (fully customizable)
- **Photographer attribution** — shown in the menu bar dropdown

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ (included with Xcode Command Line Tools)
- An Unsplash API key (free)

## Getting an Unsplash API Key

1. Go to [unsplash.com/developers](https://unsplash.com/developers) and create an account (or log in)
2. Click **Your apps** → **New Application**
3. Accept the API guidelines
4. Fill in the application details:
   - **Name:** WallSpan
   - **Description:** A macOS menu bar utility that downloads high-resolution landscape photographs from Unsplash and spans them as wallpaper across single or multi-monitor setups.
5. Copy the **Access Key** (you do not need the Secret Key)

## Building from Source

Make sure you have Swift installed (comes with Xcode Command Line Tools):

```bash
xcode-select --install   # skip if already installed
swift --version           # verify Swift is available
```

Clone the repo and build:

```bash
cd WallSpan
bash scripts/build.sh
```

This compiles the project and creates `WallSpan.app` in the project root.

## Running

```bash
open WallSpan.app
```

1. Click the photo icon in the menu bar (top-right area)
2. Click **Preferences...**
3. Paste your Unsplash Access Key and click **Save**
4. The first wallpaper will load automatically

## Installing to Applications

```bash
cp -r WallSpan.app /Applications/
```

## Installing on Another Mac

### Option A: Clone and run (no Xcode required)

The pre-built `WallSpan.app` binary is included in the repo:

```bash
git clone <repo-url>
cd WallSpan
shasum -a 256 -c CHECKSUMS.sha256   # verify binary integrity
xattr -cr WallSpan.app
open WallSpan.app
```

The `xattr -cr` removes the quarantine flag so macOS allows it to run.

### Option B: Build on the target Mac

Requires Xcode Command Line Tools (`xcode-select --install`):

```bash
git clone <repo-url>
cd WallSpan
bash scripts/build.sh
open WallSpan.app
```

### Option C: Transfer the built app

1. Copy `WallSpan.app` to the other Mac (AirDrop, USB, etc.)
2. macOS will quarantine the app since it's unsigned. To allow it:
   - **Right-click** the app → **Open** → click **Open** in the dialog (one-time step)
   - Or run in Terminal: `xattr -cr /path/to/WallSpan.app`
3. The app stores preferences (API key, search terms, interval) in `~/Library/Preferences/com.wallspan.app.plist`, so each Mac needs its own API key entry via Preferences

### Note on code signing

WallSpan is ad-hoc signed during the build, which is sufficient for running on your own machines. For distribution to others without the Gatekeeper prompt, you would need an Apple Developer account ($99/year) for Developer ID signing and notarization.

## Menu Bar Controls

| Action | Description |
|---|---|
| **Next Wallpaper** | Immediately fetch and apply a new wallpaper |
| **Pause/Resume Auto-Rotate** | Toggle the auto-rotation timer |
| **Preferences...** | Set API key, rotation interval, and search terms |
| **Quit WallSpan** | Exit the app |

## Configuration

All settings are accessible from **Preferences** in the menu bar dropdown:

- **Unsplash API Key** — your access key
- **Rotation interval** — 30 minutes, 1 hour, 6 hours, 12 hours, or 24 hours
- **Search terms** — one per line; the app randomly picks a term for each rotation

## How Multi-Monitor Spanning Works

1. Detects all connected screens and their arrangement (position, resolution)
2. Computes a bounding box encompassing the full virtual desktop
3. Downloads a landscape photo sized to the combined pixel width
4. Scales the image to fill the bounding box (aspect fill)
5. Crops each monitor's slice based on its position in the arrangement
6. Sets each slice as the wallpaper for the corresponding screen

This works with any number of monitors in any arrangement (side-by-side, stacked, offset).

## File Locations

| Path | Contents |
|---|---|
| `~/Library/Application Support/WallSpan/` | Downloaded wallpaper images (auto-cleaned on rotation) |
| `~/Library/Preferences/com.wallspan.app.plist` | App preferences |
