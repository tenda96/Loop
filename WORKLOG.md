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

Current phase: implementation complete for the first code pass; remote Xcode build preparation is in progress because full Xcode is not installed locally.

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
- [ ] Push the feature branch and establish a clean remote Xcode build.

### Next steps

1. Connect the local checkout to `https://github.com/tenda96/Loop.git` and push the feature branch.
2. Run the fork-only GitHub Actions workflow on a macOS runner with Xcode 26.4.
3. Resolve any compiler, concurrency, test, or formatting findings from the full toolchain.
4. Download the identifiable `Loop Adjacent Test.app` artifact.
5. Install it locally, grant Accessibility access, and verify launch/runtime health.
6. Prepare the user's manual test checklist and request feedback.

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
