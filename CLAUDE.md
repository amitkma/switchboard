# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Switchboard is a macOS menu bar app that acts as the default browser and sends each http/https link to an installed browser based on user-editable domain rules. There are no package dependencies.

- `Switchboard/SwitchboardApp.swift`: scenes and `AppDelegate`. All links arrive through `application(_:open:)`, on launch and while running.
- `Switchboard/RoutingRules.swift`: `Browser`, `Rule` and `DomainMatcher`. This has no UI or AppKit dependency.
- `Switchboard/LinkRouter.swift`: browser discovery, `RouterStore` (settings in UserDefaults) and `LinkRouter` (opens links through `NSWorkspace`, shows the missing-browser alert).
- `Switchboard/DefaultBrowser.swift`: `DefaultBrowserStatus`, which checks and requests the default-browser role.
- `Switchboard/SettingsView.swift`: the settings window.
- `SwitchboardTests/`: Swift Testing tests for `DomainMatcher`.
- `Info.plist` (project root): declares the http/https URL types and the `public.html` document type, merged into the generated plist. Keep it outside `Switchboard/` so it isn't also copied in as a resource.

The settings `Window` scene must keep `.handlesExternalEvents(matching: [])`. Without it, SwiftUI opens the window whenever a link arrives.

The settings window opens by itself only once, on the first launch that finds another default browser. Running the tests launches the app as their host, which uses up that first launch. To see it again, run `defaults delete ~/Library/Containers/io.github.amitkma.switchboard/Data/Library/Preferences/io.github.amitkma.switchboard defaultBrowserPromptShown`.

The rules list is a `ScrollView`, not a `List`. In a `List`, clicking a domain field took about 1.1 seconds to start editing, likely from the table class behind it. `.onMove` needs a `List`, so reordering is a `DragGesture` on the row handle. Synthetic `NSEvent`s don't trigger `DragGesture`, so test dragging by hand.

## Commands

```sh
# Build
xcodebuild -project Switchboard.xcodeproj -scheme Switchboard -destination 'platform=macOS,arch=arm64' build

# Run all tests
xcodebuild -project Switchboard.xcodeproj -scheme Switchboard -destination 'platform=macOS,arch=arm64' test

# Run one test
xcodebuild -project Switchboard.xcodeproj -scheme Switchboard -destination 'platform=macOS,arch=arm64' test -only-testing:'SwitchboardTests/DomainMatcherTests/firstMatchingRuleWins()'

# Watch routing decisions (in zsh, `log` is a builtin, so use the full path)
/usr/bin/log stream --predicate 'subsystem == "io.github.amitkma.switchboard"' --style compact --level info
```

There is no linter or formatter configuration.

CI (`.github/workflows/ci.yml`) runs the tests and a Release build on the `xcode-27` runner, a GitHub public preview whose default Xcode can be older than the local one. No signing identity is needed, because builds without a team are signed ad hoc.

To publish a release, push a version tag: `git tag v1.0.0 && git push origin v1.0.0`. `.github/workflows/release.yml` then runs the tests, builds the universal app with the tag as its version, and attaches an ad hoc signed zip to a GitHub Release. The app is not notarized.

Launch Services doesn't list copies built under `/tmp` as candidate browsers, so test default-browser behavior with a build from Xcode's normal DerivedData location.

## Project setup

- **Project file format:** `Switchboard.xcodeproj/project.xcproj` is a JSON-style text file, not a traditional `project.pbxproj`. Edit build settings there. `product-type` values omit the `com.apple.product-type.` prefix.
- **Scheme:** the shared `Switchboard` scheme in `xcshareddata/` holds the test action. Xcode's auto-generated schemes have none.
- **Adding source files:** `Switchboard/` and `SwitchboardTests/` are folders with target membership, so new files join their target without any project file change. Non-source files placed there may be treated as app resources.
- **Default configuration:** command-line builds without `-scheme` use `Release`.

## Constraints

- **Platform:** macOS only, with a deployment target of 15.0, so check API availability against macOS 15. `LSUIElement` is on, so there is no Dock icon, and code that shows a window or alert must call `NSApp.activate()` first.
- **Bundle ID:** the default-browser choice and saved settings are tied to `io.github.amitkma.switchboard`, so changing it makes users select the app again and loses their settings.
- **Concurrency:** `SWIFT_DEFAULT_ACTOR_ISOLATION` is `MainActor`, so types and functions are main-actor isolated unless marked otherwise. Use `nonisolated` or an explicit actor for background work. `SWIFT_APPROACHABLE_CONCURRENCY` is also on, with `SWIFT_VERSION` 5.0. The test target doesn't set the default, so test suites need `@MainActor`.
- **Imports:** `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on, so each file must import the module whose members it uses.
- **Entitlements:** `Switchboard.entitlements` (project root) enables the App Sandbox and read-only access to user-selected files. Release builds get exactly what that file lists, because `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` is `NO` for Release, so entitlements set only through build settings such as `ENABLE_APP_SANDBOX` don't reach Release. Add new ones to the file. The release workflow fails if the sandbox is missing or `get-task-allow` is present.
- **Generated symbols:** asset catalog and string catalog Swift symbols are generated, and most of the Info.plist is generated from `INFOPLIST_KEY_*` build settings.
