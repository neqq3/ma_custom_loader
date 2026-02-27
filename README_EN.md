# Music Assistant Custom Loader Repository

This repository provides a custom Home Assistant Add-on for Music Assistant with support for loading custom providers from `/share`.

## Available Add-on

### Music Assistant (Custom Loader)
- **Slug**: `ma-custom-loader`
- **Description**: Standard Music Assistant add-on with custom provider injection.
- **Features**:
  - Loads custom providers from `/share/music_assistant/custom_providers`
  - Full Ingress support
  - Uses default Music Assistant ports

> The coexistence variant is no longer maintained and is hidden from this repository.

## Auto-sync Policy

This repo includes scheduled automation that checks the latest `music-assistant/server` release and updates add-on metadata automatically before publishing images.

## Installation

1. Add this repository URL in Home Assistant Add-on Store:
   `https://github.com/neqq3/ma_custom_loader`
2. Install `Music Assistant (Custom Loader)`.

## Usage

1. Create `/share/music_assistant/custom_providers`
2. Place your custom provider folders there
3. Restart the add-on
