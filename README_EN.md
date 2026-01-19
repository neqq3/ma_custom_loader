# Music Assistant Custom Loader Repository

This repository provides custom versions of the Music Assistant Home Assistant Add-on, featuring support for loading custom plugins from the `/share` directory.

## Available Add-ons

### 1. Music Assistant (Custom Loader)
- **Slug**: `ma-custom-loader`
- **Description**: The standard version with custom plugin support.
- **Use Case**: Use this if you want a single Music Assistant instance with custom plugins.
- **Features**:
  - Loads custom providers from `/share/music_assistant/custom_providers`
  - Full Ingress support (Sidebar)
  - Uses default ports (8095/8097)

### 2. Music Assistant (Coexistence)
- **Slug**: `ma-custom-loader-coexist`
- **Description**: A special version designed to run alongside the official Music Assistant Add-on.
- **Use Case**: Use this if you want to keep the official Add-on running while testing custom plugins.
- **Features**:
  - **Port Conflict Resolution**: Automatically patches internal ports to avoid conflicts (Web: 8099, Stream: 8098, Ingress: 8093).
  - **Ingress Support**: Enabled on port 8093.
  - Loads custom providers from `/share/music_assistant/custom_providers`

## Installation

1. Add this repository URL to your Home Assistant Add-on Store:
   `https://github.com/neqq3/ma_custom_loader`
2. Install the desired Add-on.

## Usage

To load custom plugins:
1. Create a directory: `/share/music_assistant/custom_providers`
2. Place your plugin folders inside this directory.
3. Restart the Add-on.
