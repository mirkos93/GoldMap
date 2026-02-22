# GoldMap (WoW Classic Era)

<p align="center">
  <img src="logo.png" alt="GoldMap logo" width="220" />
</p>

GoldMap helps you farm gold with less guesswork.

It shows profitable targets directly on **World Map** and **Minimap**, combining:
- curated drop/yield + spawn data
- your local Auction House market data from **Auctionator** (required)

## What You Get

- Mob farm pins (value per kill)
- Gathering pins for herbs and ore (value per node)
- Clear tooltips with:
  - item links
  - chance/yield and count context
  - market value and contribution
- Filters built for real gameplay:
  - droprate range
  - estimated gold range
  - minimum item price
  - quality floor
  - reliability floor
  - selling speed floor
  - mob level + difficulty
  - narrow/broad logic mode
- Presets + custom presets
- Market freshness advisor

## Market Data and Stability

- GoldMap syncs with Auctionator via `/goldmap scan`
- Confidence and sell-speed labels are based on local historical signals
- Outlier guard reduces distorted values from extreme AH listings
- Non-attackable/non-practical city targets are excluded by design
- If an item has no usable sample yet, tooltips show **No price yet** and value as `--`

## Quick Setup

1. Install and enable Auctionator
2. Run Auctionator scan at AH
3. Run `/goldmap scan`
4. Open filters and start farming

Auctionator:
- GitHub: https://github.com/TheMouseNest/Auctionator/
- CurseForge: https://www.curseforge.com/wow/addons/auctionator

## Commands

- `/goldmap`
- `/goldmap filters`
- `/goldmap scan`
- `/goldmap advisor`
- `/goldmap refresh`
- `/goldmap debug`
- `/goldmap luadebug`

Built for **WoW Classic Era**.
