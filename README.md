# GoldMap

<p align="center">
  <img src="logo.png" alt="GoldMap logo" width="220" />
</p>

**GoldMap** is a World of Warcraft Classic Era addon that helps you farm smarter, not harder.
It shows profitable farm targets directly on the **World Map** and **Minimap** by combining seed loot/gather data with your local Auction House prices.

If your goal is simple, **more gold per hour with less guesswork**, GoldMap is built for exactly that.

## Why Players Like GoldMap

- It turns farming from "random grinding" into **data-driven routing**.
- It highlights where value is, **right now**, based on your AH snapshot.
- It keeps the workflow in-game: map pins, tooltips, filters, and Auctionator-powered sync.

## Core Features

- Profit-oriented pins on **World Map** and **Minimap**
- Support for:
  - mob farming (loot EV per kill)
  - gathering farming (herbs/ore EV per node)
- Rich tooltips with:
  - top valuable items
  - chance/yield and quantity context
  - market value and EV contribution
- Powerful filters with friendly labels:
  - mob droprate range
  - EV range (mob and gathering)
  - item price floor
  - minimum selling speed (`None/Low/Medium/High`)
  - quality floor
  - mob level range
  - filter logic mode: `Match all` / `Match any`
- Auctionator-backed market sync (`/goldmap scan`)
- First-run welcome screen + Help/Glossary
- Always excludes non-attackable/non-practical farm targets

## Quick Start

1. Install GoldMap in `Interface/AddOns/GoldMap`
2. Install Auctionator (required dependency)
3. Launch the game and run `/goldmap`
4. Run an Auctionator scan to refresh market data
5. Run `/goldmap scan` to sync GoldMap from Auctionator cache
6. Open map filters and tune your farm strategy
7. Follow high-value pins on map/minimap

## Recommended Flow (Fastest Results)

1. Run an Auctionator scan first
2. Run `/goldmap scan` to import latest cache
3. Set minimum item price
4. Set minimum estimated gold
5. Reduce clutter with quality and level filters
6. Move zone-to-zone using map pins and tooltip EV

## How To Reach High Confidence

GoldMap confidence is based on local Auctionator history quality.

1. Run scans regularly (not one single scan).
2. Keep scans recent (old snapshots lose confidence).
3. Sync often with `/goldmap scan`.
4. Focus filters on items with stable demand and repeated observations.
5. Confidence uses price age, history depth, exact snapshot coverage, and observed availability.
6. It is not a direct "items sold per day" metric (that signal is not exposed by Auctionator API).
7. Hold `Shift` on tooltips for technical market details; default tooltip stays simple.

## What "Estimated Gold" Means

GoldMap uses expected value:

`Estimated Gold = sum(chance_or_yield * average_count * market_price)`

It is an estimate, not a guarantee, but it is a very practical way to compare farm targets consistently.

## Slash Commands

- `/goldmap` or `/gmfarm`: open settings
- `/goldmap filters`: open map filters popup
- `/goldmap scan`: sync prices from Auctionator cache
- `/goldmap stop`: no-op (legacy command)
- `/goldmap refresh`: force map refresh
- `/goldmap debug`: toggle GoldMap debug logs
- `/goldmap luadebug`: toggle global Lua errors
- `/goldmap welcome`: show welcome window again

## Compatibility

- Game target: **WoW Classic Era**
- Not designed for Retail
- Not designed for Season of Discovery

## Share GoldMap

If GoldMap improves your farm routes, please help it grow:

- Share it with guildmates and friends
- Post feedback and screenshots
- Open issues with reproducible steps when you find edge cases

Every report helps improve route quality, scan reliability, and overall farming UX.

---

## Development

This section is technical and intended for contributors.

### Project Structure

- `Core/`: initialization, events, evaluators, message bus
- `AHScan/`: Auctionator sync + local cache + confidence scoring
- `Map/`: world map + minimap pin rendering
- `UI/`: options, filter popup, tooltips, overlays
- `Data/`: generated Lua seed datasets
- `Utils/`: throttling, projection, IDs, generic helpers

### Runtime Data Flow

1. Offline extraction builds compact Lua data from MySQL
2. Auctionator collects market data
3. GoldMap syncs tracked item prices from Auctionator cache
4. Evaluators compute EV for mobs and gather nodes
5. Filters are applied
6. Pins/tooltips/overlays render only matching targets

### Data Extraction (MySQL -> Lua)

Set environment variables:

```bash
export GM_DB_HOST=localhost
export GM_DB_USER=mirko
export GM_DB_PASS='your_password'
export GM_DB_NAME=wow
```

Run extraction pipeline:

```bash
./scripts/extract_goldmap_data.sh
```

Generated datasets:

- `Data/SeedDrops.lua`
- `Data/Spawns.lua`
- `Data/Zones.lua`
- `Data/GatherNodes.lua`
- `Data/GatherSpawns.lua`

### Release Automation

Workflow file:

- `.github/workflows/release.yml`

On tag (example `v0.1.0`), it can:

- build `GoldMap-vX.Y.Z.zip`
- create GitHub release
- optionally publish to CurseForge

Expected secrets/vars:

- `CF_API_TOKEN` (secret)
- `CF_PROJECT_ID` (variable)
- `CF_GAME_VERSIONS` (variable)

### Security Notes

- No DB password hardcoded in source
- Prefer `GM_DB_PASS` env var
- `.gitignore` excludes common sensitive/build artifacts

### Improvement Ideas

- Better spawn validation and coordinate outlier pruning
- Route mode that prioritizes nearest profitable targets
- Better low-zoom map clustering and decluttering
- Optional debug snapshot export for bug reports
- Smarter confidence model using trend/volatility buckets

### Future Features

- Fishing support
- Skinning support

## License

Add project license/distribution terms before broad public release.
