<a href="https://apps.apple.com/us/app/void-meditation/id6738365261?itscg=30200&itsct=apps_box_artwork&mttnsubad=6738365261" style="position: relative; width: 40px; height: 40px; overflow: hidden; display: inline-block; vertical-align: middle; 
--app-icon-mask: url('data:image/svg+xml,%0A%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20xml%3Aspace%3D%22preserve%22%20viewBox%3D%220%200%20230.5%20230.5%22%3E%0A%20%20%3Cpath%20fill-rule%3D%22evenodd%22%20stroke-linejoin%3D%22round%22%20stroke-miterlimit%3D%221.4%22%20clip-rule%3D%22evenodd%22%20d%3D%22M158.2%20230H64.1a320%20320%200%200%201-7-.1c-5%200-10-.5-15-1.3a50.8%2050.8%200%200%201-14.4-4.8%2048.2%2048.2%200%200%201-21-21%2050.9%2050.9%200%200%201-4.8-14.4%20100.7%20100.7%200%200%201-1.3-15v-7l-.1-8.2V64.1a320%20320%200%200%201%20.1-7c0-5%20.5-10%201.3-15a50.7%2050.7%200%200%201%204.8-14.4%2048.2%2048.2%200%200%201%2021-21%2051%2051%200%200%201%2014.4-4.8c5-.8%2010-1.2%2015-1.3a320%20320%200%200%201%207%200l8.2-.1h94.1a320%20320%200%200%201%207%20.1c5%200%2010%20.5%2015%201.3a52%2052%200%200%201%2014.4%204.8%2048.2%2048.2%200%200%201%2021%2021%2050.9%2050.9%200%200%201%204.8%2014.4c.8%205%201.2%2010%201.3%2015a320%20320%200%200%201%20.1%207v102.3l-.1%207c0%205-.5%2010-1.3%2015a50.7%2050.7%200%200%201-4.8%2014.4%2048.2%2048.2%200%200%201-21%2021%2050.8%2050.8%200%200%201-14.4%204.8c-5%20.8-10%201.2-15%201.3a320%20320%200%200%201-7%200l-8.2.1z%22%2F%3E%0A%3C%2Fsvg%3E%0A');">

  <img src="https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/50/53/9b/50539b47-15b4-536f-32dd-9f60e692c75a/AppIcon-0-0-1x_U007ephone-0-1-85-220.png/540x540bb.jpg" alt="Void — Meditation"
       style="width: 60px; height: 60px; object-fit: contain;
       mask-image: var(--app-icon-mask); -webkit-mask-image: var(--app-icon-mask);" />

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 230.5 230.5" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; box-sizing: border-box;">
<path fill="none" stroke="#000" stroke-linejoin="round" stroke-miterlimit="1.4" stroke-opacity=".1" stroke-width="1" d="M158.2 230H64.1a320 320 0 0 1-7-.1c-5 0-10-.5-15-1.3a50.8 50.8 0 0 1-14.4-4.8 48.2 48.2 0 0 1-21-21 50.9 50.9 0 0 1-4.8-14.4 100.7 100.7 0 0 1-1.3-15v-7l-.1-8.2V64.1a320 320 0 0 1 .1-7c0-5 .5-10 1.3-15a50.7 50.7 0 0 1 4.8-14.4 48.2 48.2 0 0 1 21-21 51 51 0 0 1 14.4-4.8c5-.8 10-1.2 15-1.3a320 320 0 0 1 7 0l8.2-.1h94.1a320 320 0 0 1 7 .1c5 0 10 .5 15 1.3a52 52 0 0 1 14.4 4.8 48.2 48.2 0 0 1 21 21 50.9 50.9 0 0 1 4.8 14.4c.8 5 1.2 10 1.3 15a320 320 0 0 1 .1 7v102.3l-.1 7c0 5-.5 10-1.3 15a50.7 50.7 0 0 1-4.8 14.4 48.2 48.2 0 0 1-21 21 50.8 50.8 0 0 1-14.4 4.8c-5 .8-10 1.2-15 1.3a320 320 0 0 1-7 0l-8.2.1z" clip-rule="evenodd" vector-effect="non-scaling-stroke"/>
</svg>
</a>

# Void — Meditation Timer

This is **Void**, a simple meditation timer built with **SwiftUI** and the [Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture). 
This repository demonstrates how to structure a small-to-medium app using the composable architecture. 

This is by no means a perfect codebase, but I hope open-sourcing it might help others learn to use these wonderful tools. Feel free to open up an issue with any questions or comments you may have. Have fun and enjoy! 🙇‍♂️ 

Oh, and download the app! — And review it if you like it!

<a href="https://apps.apple.com/us/app/void-meditation/id6738365261?itscg=30200&itsct=apps_box_badge&mttnsubad=6738365261" style="display: inline-block;">
<img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us?releaseDate=1732579200" alt="Download on the App Store" style="width: 246px; height: 82px; vertical-align: middle; object-fit: contain;" />
</a>


---

## Overview

- **SwiftUI + TCA**: We organize the app into **features**, each with its own `@Reducer`, `State`, `Action`, and SwiftUI views.
- **Dependency Injection**: External services (e.g. HealthKit, Audio) are encapsulated as “clients” using TCA’s `DependencyKey`.
- **Feature Folders**: Each major app section (like **Onboarding**, **Settings**, **Timer**, etc.) lives in its own folder under [`Features`](./Void/Features).
- **Reusable Components**: Shared logic and helpers (e.g. `SoundManager`, `HealthKitClient`) live in [`Clients`](./Void/Clients) and [`Utilities`](./Void/Utilities).

Below is a quick tour of the major directories and files.

---

## Project Structure

### Features

Each feature folder contains:
1. A **Reducer** (`FeatureNameFeature.swift`) defining `State`, `Action`, and any side effects.
2. A **View** file (`FeatureNameView.swift`) binding to the reducer’s state.

**Highlights**:
- [`OnboardingFeature.swift`](./Void/Features/Onboarding/OnboardingFeature.swift)  
  Handles the initial onboarding flow and requests HealthKit permissions.
- [`SettingsFeature.swift`](./Void/Features/Settings/SettingsFeature.swift)  
  Manages user preferences (timer length, intervals, ambient sounds).
- [`MeditationTimerFeature.swift`](./Void/Features/Timer/MeditationTimerFeature.swift)  
  The main meditation timer logic (start/pause/play, timer completion).
- [`StatsFeature.swift`](./Void/Features/Stats/StatsFeature.swift)  
  Fetches daily and weekly meditation stats via HealthKit.

The app’s root reducer is [`HomeFeature.swift`](./Void/Features/Home/HomeFeature.swift). It ties all child features together (onboarding, settings, stats, meditation timer) and manages global app state.

### Clients

Dependencies for external or system services are in [`Clients`](./Void/Clients). Each client is implemented as a TCA `DependencyKey`:

- [`HealthKitClient.swift`](./Void/Clients/HealthKit/HealthKitClient.swift)  
  Reads and writes mindful sessions to HealthKit.
- [`SoundManager`](./Void/Clients/SoundManager/SoundManager.swift) and [`AmbientManager`](./Void/Clients/SoundManager/AmbientManager.swift)  
  Handle bell sounds, ambient loops, and audio session setup.

### Models

We store plain data models in the [`Models`](./Void/Models) folder:

- [`VoidSettings.swift`](./Void/Models/VoidSettings.swift): Holds user preferences (timer duration, ambient sound, etc.).
- [`MeditationState.swift`](./Void/Models/MeditationState.swift): Tracks the current meditation session.
- [`Quote.swift`](./Void/Models/Quote.swift): Simple struct for random quotes displayed on the home screen.

### Views and Utilities

- [`KeyboardView.swift`](./Void/Features/Keyboard/KeyboardView.swift): A custom numeric keyboard for user input.
- [`MovingLogo.swift`](./Void/Views/MovingLogo.swift) & [`LogoView.swift`](./Void/Views/LogoView.swift): Animated shape-based logos.
- [`PulseView.swift`](./Void/Views/PulseView.swift): Overlay effect that shows pulsing visuals for transitions.
- [`Constants.swift`](./Void/Utilities/Constants.swift): Global animations and style constants.
- [`PreventDeviceSleep.swift`](./Void/Utilities/PreventDeviceSleep.swift): Disables idle timer to keep the screen awake.

---

## How It Works

1. **App Launch**  
   - The root `HomeFeature` checks if HealthKit is authorized. If not, it presents the onboarding flow (`OnboardingFeature`).
2. **Meditation Flow**  
   - The user sets their **timer**, **intervals**, and **ambient sound** in the **Settings** feature.
   - Tapping **Begin** starts `MeditationTimerFeature`, which counts elapsed time and plays interval/finish bells.
   - When the user stops, the session is saved to HealthKit (if over 10 seconds).
3. **Stats & Quotes**  
   - **StatsFeature** queries HealthKit daily to display total minutes meditated and keeps track of your daily streak.
   - **QuotesView** shows random mindfulness quotes on the home screen.

---

## Patterns & Best Practices

- **Composable Architecture**: Each feature has:
  - A `@Reducer` struct with `State`, `Action`, and `body`.
- **Dependency Clients**:  
  - Wrapped in `@DependencyClient`, with `liveValue` (real implementation) and `testValue` (fake or mock).
  - Each client is registered in `DependencyValues` for easy access in reducers.
- **State Persistence**:  
  - We use TCA’s `@Shared` storage for persisting state across app launches (e.g. `VoidSettings`, `MeditationState`).

---

## Contributing

I'm more than happy to accept contributions, but I also want to keep this app simple and functional. So perhaps open up an issue before coding up too much 😜
