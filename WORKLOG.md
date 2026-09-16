# Adjacent Window Resize — Work Log

This file is the persistent implementation record for the local Loop fork. Update it whenever work starts, a decision is made, a verification is run, or the next step changes.

## Objective

Add an opt-in adjacent-window resize feature to Loop. For the first usable version, when two normal resizable windows are side by side on the same display and Space, dragging their shared vertical boundary resizes the neighboring window in the opposite direction while preserving the original gap and the neighbor's outer edge.

The user will perform application-level testing. Before handoff, the project must build, produce an installable app, and pass the technical checks that can be run locally.

## Working agreement

- Work only on the local fork unless the user explicitly asks for publication.
- Keep the upstream remote unchanged.
- Keep this log current throughout implementation.
- Preserve existing Loop behavior when the feature is disabled.
- Prefer a narrow, reliable two-window MVP before adding stacked or multi-window layouts.

## Repository state

- Local path: `/Users/luca/Documents/ChatGPT/loop fork`
- Upstream: `https://github.com/MrKai77/Loop.git`
- Base branch: `develop`
- Base commit: `df26d56` (`📄 Move "How to Contribute" section in README`)
- Working branch: `feature/adjacent-window-resize`
- Started: 2026-09-11 (Europe/Rome)

## Status

Current phase: second-pass plan approved and implemented locally; validation is in progress before the next remote build.

### Completed

- [x] User approved the implementation plan.
- [x] User chose to perform real-world application testing personally.
- [x] Empty working directory verified.
- [x] Upstream repository cloned locally.
- [x] Dedicated local feature branch created.
- [x] Persistent work log created.

### In progress

- [x] Read repository documentation and build instructions.
- [x] Map window model, Accessibility observers, mouse events, settings, and test layout.
- [x] Implement pure horizontal adjacency and coordinated-frame geometry.
- [x] Add focused geometry tests and standalone smoke coverage.
- [x] Add the runtime adjacent-resize session controller.
- [x] Integrate the controller with Loop's existing global mouse-drag manager.
- [x] Add the opt-in Behavior setting, disabled by default.
- [x] Add English and Italian string-catalog entries for the setting.
- [x] Create the GitHub fork `tenda96/Loop` from upstream `develop`.
- [x] Add a fork-specific macOS CI workflow that needs no Apple signing certificates.
- [x] Push the feature branch and establish a clean remote Xcode build.

### Next steps

1. Run formatting, parsing, JSON, standalone geometry, and diff checks for the second pass.
2. Push the second-pass implementation and run remote Xcode CI.
3. Resolve any full-toolchain findings without regressing the successful first build.
4. Install the resulting ARM64 test app and request focused user feedback.

## MVP acceptance criteria

- Loop builds and launches.
- The behavior is controlled by an explicit setting.
- With the setting disabled, existing resize behavior is unchanged.
- For two left/right adjacent resizable windows on one display, dragging the shared edge updates the other window.
- The original gap and the neighbor's outer edge remain stable.
- Minimum window sizes are respected without overlap or runaway feedback.
- Minimized, hidden, fullscreen, non-resizable, cross-display, and non-adjacent windows are ignored safely.
- Geometry logic has automated coverage; existing relevant checks still pass.
- A testable `.app` is produced and its launch is verified before user handoff.

## Decisions and assumptions

- MVP scope is a single pair of horizontally adjacent windows; vertically stacked and multi-window chains are later extensions.
- A separate local build identity/name is preferred if it can be introduced without destabilizing signing or Accessibility permissions.
- Fine-grained compatibility findings belong in the user feedback phase rather than blocking the first handoff.
- Candidate discovery reuses Loop's on-screen window list, then explicitly filters to the source display; off-Space windows are therefore not selected.
- The first-pass adjacency tolerance is 32 points, with up to 2 points of overlap tolerated for application border/AX rounding differences.
- A generic 80-point safety minimum is applied first. If the neighboring app enforces a larger minimum, its applied AX width is read back and used to clamp the shared boundary.
- If this work is ever proposed upstream, Loop's `AI_POLICY.md` requires explicit AI-assistance disclosure and full human verification.

## Verification history

- 2026-09-11: repository cloned successfully from upstream.
- 2026-09-11: confirmed checked-out upstream branch was `develop` at `df26d56`.
- 2026-09-11: created local branch `feature/adjacent-window-resize`.
- 2026-09-11: read `CONTRIBUTING.md` and `AI_POLICY.md`; any future upstream contribution must disclose Codex assistance and be manually verified by the user.
- 2026-09-11: identified `WindowDragManager` as the existing global left-drag integration point. It already resolves the dragged window and distinguishes move vs. resize operations.
- 2026-09-11: identified `WindowUtility.windowList()` for active on-screen candidates and `Window.setFrameSynchronously()` for live neighbor updates.
- 2026-09-11: baseline `xcodebuild` could not start because only Command Line Tools are active and no full Xcode installation is currently visible in `/Applications`. Swift 6.2.3 command-line tools are available, so implementation and limited syntax/logic verification can continue; app build/install verification will require Xcode.
- 2026-09-11: the default Command Line Tools SDK 26.2 could not type-check because its Swift module version differs from the installed Swift driver; SDK 15.4 successfully type-checked the standalone geometry source.
- 2026-09-11: compiled and ran standalone geometry smoke checks with Swift 6.2.3 and the macOS 15.4 SDK; right-edge, left-edge, gap preservation, outer-edge preservation, and minimum-width clamping passed.
- 2026-09-11: all modified Swift files passed frontend parsing.
- 2026-09-11: `git diff --check` passed and `Loop/Localizable.xcstrings` passed JSON validation with `jq`.
- 2026-09-11: full target tests, app bundling, installation, and launch remain unverified until Xcode is available.
- 2026-09-15: created the public GitHub fork `tenda96/Loop`, copying the upstream `develop` branch.
- 2026-09-15: added `.github/workflows/fork-test-build.yml`. It runs formatting and the Loop test target on GitHub's `macos-26` runner using Xcode 26.4, builds without Apple certificates, applies an ad-hoc signature, assigns the test-only main bundle identifier `com.tenda96.LoopAdjacentTest`, and uploads `Loop-Adjacent-Test.zip`.
- 2026-09-15: first remote run `34971925891` successfully selected Xcode 26.4 and resolved every Swift package, then stopped at SwiftFormat before compilation because one continuation line in `AdjacentWindowResizeController.swift` was over-indented. Corrected the reported indentation and queued a second run.
- 2026-09-15: second remote run `34972130222` passed dependency resolution and SwiftFormat. Xcode compiled and linked the application and `LoopTests` successfully, confirming that the first-pass feature code builds with Xcode 26.4. Test execution then timed out because the hosted test application had been built completely unsigned (`The test runner hung before establishing connection`). Changed only the test step to use macOS ad-hoc signing so the test host can launch without Apple certificates.
- 2026-09-15: third remote run `34973347608` confirmed that ad-hoc signing completed successfully for Loop, its updater helper, Dock Tile plugin, and `LoopTests`, but the hosted Loop process still did not establish an XCTest connection on the headless runner and timed out after 353 seconds. This isolates the failure to launching the GUI test host in GitHub Actions rather than compilation or signing.
- 2026-09-15: replaced hosted test execution in fork CI with `xcodebuild build-for-testing`, which still compiles the entire app and the complete `LoopTests` target. Added a standalone executable smoke suite for adjacent-resize geometry so the new pure logic is executed without launching the GUI app. The workflow continues to build and package the development `.app` only after both checks succeed.
- 2026-09-15: fourth remote run `34974767088` passed package resolution, SwiftFormat, full application/test-target compilation, and the standalone adjacent-resize geometry smoke suite. Only the later Development artifact build failed: it reused the Debug build's `DerivedData` while requesting a universal arm64/x86_64 product, producing corrupted or architecture-incompatible dependency modules and missing x86_64 Loop modules. Isolated the artifact build in `BuildDerivedData` and restricted the personal test package to arm64, matching the user's Apple Silicon Mac.
- 2026-09-15: fifth remote run `34977633964` succeeded end to end: dependency resolution, SwiftFormat, full application and test-target compilation, standalone adjacent-resize checks, ARM64 Development app build, ad-hoc signing, verification, and artifact upload all passed.
- 2026-09-15: downloaded `Loop-Adjacent-Test.zip` to `artifacts/run-34977633964`, extracted it, confirmed the packaged app's signature is valid, verified its `arm64` executable and test-only bundle ID `com.tenda96.LoopAdjacentTest`, and matched the installed `/Applications/Loop Adjacent Test.app` executable byte-for-byte to the CI artifact. The installed app launched successfully and remained active as process `9344`; application-level behavior is now handed to the user for testing.
- 2026-09-15: initial user test confirmed that the custom app launches without problems. It still offered an upstream Loop update and did not provide the expected occupied-space-aware placement or linked resize behavior.
- 2026-09-15: diagnosed the update prompt: the inherited updater explicitly queries `MrKai77/Loop` GitHub releases, and updates remain enabled for the custom bundle. Diagnosed the missing linked resize: the test bundle has `useSystemWindowManagerWhenAvailable = true`, while `resizeAdjacentWindows` has no stored true value and therefore remains at its false default; the current Behavior UI also hides the adjacent-resize toggle whenever system window-manager integration is enabled. The runtime controller consequently never executed during the user's test.
- 2026-09-15: confirmed that upstream's existing `Fill Available Space` action is not directional. It searches for a globally largest non-overlapping rectangle and ignores windows already intersecting the target's current frame, so it does not implement “place on the right and consume exactly the region left beside the existing window.” A dedicated configurable side-placement policy is required.
- 2026-09-15: user approved the second-pass plan and confirmed that linked horizontal resizing works after disabling macOS window-manager integration and enabling the previously hidden toggle, but remains inconsistent in some arrangements. The user also requested resizing from additional sides.
- 2026-09-15: implemented second-pass changes locally: personal test builds now disable all updater checks; adjacent resizing and occupied-space side placement are independently visible Behavior settings and default on for the personal bundle; left/right half actions can use the boundary of a qualifying full-height window on the opposite side, falling back to standard halves; system window-manager dispatch is bypassed only for those adaptive side actions; resize capture begins on mouse-down; and linked resizing now supports left, right, top, and bottom shared edges.
- 2026-09-15: expanded XCTest and standalone smoke coverage for four-edge geometry, minimum-size clamping, adaptive right-side placement, and fallback behavior. The standalone Swift 6.2.3 geometry suite passed against the matching macOS 26.2 SDK; all changed Swift sources passed frontend parsing and the string catalog remained valid JSON.
- 2026-09-16: resumed from the persistent log and repeated the complete local preflight. Four-edge and adaptive-placement smoke checks passed; every changed Swift source parsed; the workflow parsed as YAML; the localization catalog parsed as JSON; and `git diff --check` passed. The second pass is ready for remote Xcode validation.
- 2026-09-16: second-pass remote run `35098750305` resolved dependencies successfully but stopped before compilation because SwiftFormat's `preferKeyPath` rule rejected the new identity `compactMap` closure. Replaced it with the required `compactMap(\.self)` form; no runtime or geometry logic changed.

## Environment blocker

- macOS: 26.5.1 (25F80)
- Installed Swift driver: 6.2.3
- Active developer directory: Command Line Tools only
- Full Xcode: not installed or not discoverable
- Free space observed on the data volume: approximately 35 GiB; Xcode installation may require freeing additional space.
- Detailed tool inventory: Apple Clang 17, Swift Package Manager 6.2.3, macOS 15.4 and 26.2 SDK directories, and `codesign` are present.
- `/usr/bin/xcodebuild` and `/usr/bin/actool` are dispatcher stubs; both refuse project/asset builds while the active developer directory is Command Line Tools.
- No Xcode app was found through Spotlight or in `/Applications`, `/Users/luca/Applications`, or `/Library/Developer`.
- No alternative Xcode project generators/build frontends (`xcodegen`, `tuist`, `xcbeautify`) or SwiftFormat installation were found.
- Building full Loop manually with SwiftPM would require a parallel packaging system for 154 Swift files, four package dependencies, generated asset symbols, 113 asset files, the Dock Tile plugin, updater helper, localization catalog, private SkyLight linking, Info.plist generation, and signing. This is possible as a separate engineering effort but is not equivalent to verifying the upstream build.
- Viable no-local-Xcode alternative: build the branch on a remote macOS CI runner, download the app artifact, then ad-hoc sign and verify it locally. This requires explicit authorization and access to a remote Git repository/CI service.

## Open questions to resolve from the code

- Resolved: reuse `WindowDragManager` and its passive `.leftMouseDragged`/`.leftMouseUp` event taps.
- Resolved: `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` supplies active on-screen candidates; add an explicit same-display check with `ScreenUtility.screenContaining`.
- Resolved: add the opt-in preference to the existing Behavior → Window section.
- Which application identity/signing adjustment gives a test build without breaking Accessibility authorization? Resolve after the first successful full build.
- Does the full Xcode compiler require additional actor/sendability annotations around the synchronous drag callback? Resolve during the first full target build.
