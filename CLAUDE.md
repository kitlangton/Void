# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Void is a minimalist meditation timer iOS app built with SwiftUI and The Composable Architecture (TCA). The app focuses on simplicity, allowing users to meditate with ambient sounds, interval bells, and HealthKit integration.

## Architecture

The app follows TCA (The Composable Architecture) patterns:
- Each feature has its own folder containing a Reducer and View
- Dependencies are injected through TCA's dependency system
- State is managed through TCA's @Shared mechanism for persistence
- Features communicate through parent-child reducer composition

Key architectural components:
- **VoidApp.swift**: Main app entry point with root store
- **Features/**: Each major screen has its own feature module (Home, Timer, Stats, Settings, Onboarding)
- **Clients/**: External service wrappers (HealthKit, SoundManager, StatsClient)
- **Models/**: Shared data models used across features

## Development Commands

Since this is an Xcode project, standard Xcode commands apply:
- Build: `⌘+B` in Xcode or `xcodebuild build`
- Run: `⌘+R` in Xcode
- Clean: `⌘+⇧+K` in Xcode or `xcodebuild clean`

## Key Dependencies

- **swift-composable-architecture** (1.17.1): Main architecture framework
- **Pow**: Animation effects library
- **swift-dependencies**: Dependency injection
- **swift-shared-state**: State persistence

## Important Implementation Details

1. **Timer Implementation**: Uses TCA's clock for accurate timing with background support
2. **Sound Management**: Custom SoundManager and AmbientManager handle audio playback
3. **HealthKit Integration**: Saves meditation sessions to Apple Health
4. **State Persistence**: Settings and stats stored using TCA's @Shared with AppStorage
5. **Background Audio**: Configured with proper audio session categories for background playback

## Code Conventions

- Feature modules follow the pattern: `[Feature]Feature.swift` for reducers
- Views are either embedded in feature files or separate `[Feature]View.swift` files
- Dependencies use TCA's `@Dependency` property wrapper
- State changes happen only through reducer actions