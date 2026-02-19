# GoldMap (Classic Era)

<p align="center">
  <img src="logo.png" alt="GoldMap logo" width="220" />
</p>

GoldMap helps you find the best farming mobs in WoW Classic Era by combining:

- drop chances from a curated seed dataset
- spawn positions on map and minimap
- your local Auction House market prices

The result is a practical, in-game farming overlay focused on **estimated gold per kill**.

## Why use GoldMap

- You see profitable farm targets directly on the map.
- You can filter aggressively (or broadly) depending on your goal.
- Tooltips explain exactly where value comes from (drop chance, price, estimated contribution).

## Main Features

- World Map and Minimap farm pins
- Rich pin and mob tooltips
- Estimated Gold-per-kill calculation
- Filters:
  - Min/Max droprate
  - Min/Max Estimated Gold per kill
  - Min item price
  - Min selling speed (None/Low/Medium/High)
  - Min item quality
  - Min/Max mob level
  - Include targets with no market price yet
  - Non-attackable targets are always excluded
  - Narrow mode (match all filters) / Broad mode (match any filter)
- Auctionator-backed market sync (`/goldmap scan`)
- Market confidence labels (Low/Medium/High)

## What “Estimated Gold” means

Estimated Gold = Expected Value per kill.

GoldMap computes:

`sum(drop chance * average drop count * market price)`

So you can compare farms by average value, not just by single lucky drops.

## Auction House Data

- Auctionator is required.
- Auctionator GitHub: https://github.com/TheMouseNest/Auctionator/
- Auctionator CurseForge: https://www.curseforge.com/wow/addons/auctionator
- Run Auctionator scans, then use `/goldmap scan` to sync into GoldMap.
- If no market data exists yet, items show “No price yet” and Estimated Gold shows “--”.
- Hold `Shift` on tooltips for detailed market diagnostics.

## Notes

- Built for **WoW Classic Era**.
- All labels and settings are in English.
- Designed for map-first farming workflow and quick decision making.
