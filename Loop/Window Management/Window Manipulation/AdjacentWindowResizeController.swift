//
//  AdjacentWindowResizeController.swift
//  Loop
//
//  Created by Codex on 2026-09-11.
//

import AppKit
import Scribe

/// Coordinates one neighboring window with a native horizontal resize performed by the user.
///
/// A session is created only after `WindowDragManager` has confirmed that the source window is
/// changing width without changing height. Candidate discovery happens once per mouse drag; later
/// events reuse the captured frames to avoid repeated WindowServer and Accessibility enumeration.
@Loggable
@MainActor
final class AdjacentWindowResizeController {
    private struct Session {
        let sourceWindowID: CGWindowID
        let match: AdjacentWindowResizeGeometry.Match
        let neighbor: Window
        let neighborProperties: Window.ResolvedProperties
    }

    private var session: Session?
    private var didFailToCreateSession = false

    /// Updates the neighboring window for the most recent source frame.
    /// - Parameters:
    ///   - source: Window the user is resizing through the native macOS border interaction.
    ///   - initialSourceFrame: Source frame captured by `WindowDragManager` near drag start.
    ///   - currentSourceFrame: Latest source frame observed during the drag.
    func synchronize(
        source: Window,
        initialSourceFrame: CGRect,
        currentSourceFrame: CGRect
    ) {
        if session == nil, !didFailToCreateSession {
            createSession(
                source: source,
                initialSourceFrame: initialSourceFrame,
                currentSourceFrame: currentSourceFrame
            )
        }

        guard let session,
              session.sourceWindowID == source.cgWindowID,
              let initialFrames = AdjacentWindowResizeGeometry.resolvedFrames(
                  for: currentSourceFrame,
                  match: session.match
              )
        else {
            return
        }

        apply(initialFrames.neighbor, to: session)

        // Applications enforce their own minimum size after an AX write. Read the result once and,
        // when it is wider than requested, use that observed width as the effective minimum. This
        // keeps the neighbor's outer edge fixed and prevents the source from overlapping it.
        let appliedNeighborFrame = session.neighbor.frame
        let observedMinimumWidth = appliedNeighborFrame.width
        let neighborWasClamped = observedMinimumWidth > initialFrames.neighbor.width + 1

        let finalFrames: AdjacentWindowResizeGeometry.FramePair
        if neighborWasClamped,
           let correctedFrames = AdjacentWindowResizeGeometry.resolvedFrames(
               for: currentSourceFrame,
               match: session.match,
               neighborMinimumWidth: observedMinimumWidth
           ) {
            finalFrames = correctedFrames
            apply(correctedFrames.neighbor, to: session)
        } else {
            finalFrames = initialFrames
        }

        if !source.frame.approximatelyEqual(to: finalFrames.source, tolerance: 1) {
            source.setFrameSynchronously(finalFrames.source)
        }
    }

    /// Clears all state at mouse-up or when drag monitoring shuts down.
    func reset() {
        session = nil
        didFailToCreateSession = false
    }

    private func createSession(
        source: Window,
        initialSourceFrame: CGRect,
        currentSourceFrame: CGRect
    ) {
        guard !source.isOwnWindow,
              !source.minimized,
              !source.fullscreen,
              source.isResizable,
              let edge = AdjacentWindowResizeGeometry.resizedHorizontalEdge(
                  from: initialSourceFrame,
                  to: currentSourceFrame
              ),
              let sourceScreen = ScreenUtility.screenContaining(source)
        else {
            return
        }

        let candidates = WindowUtility.windowList().filter { candidate in
            guard candidate.cgWindowID != source.cgWindowID,
                  !candidate.isOwnWindow,
                  !candidate.isAppExcluded,
                  !candidate.minimized,
                  !candidate.fullscreen,
                  candidate.isResizable,
                  let candidateScreen = ScreenUtility.screenContaining(candidate)
            else {
                return false
            }

            return candidateScreen.isSameScreen(sourceScreen)
        }

        let geometryCandidates = candidates.map {
            AdjacentWindowResizeGeometry.Candidate(windowID: $0.cgWindowID, frame: $0.frame)
        }

        guard let match = AdjacentWindowResizeGeometry.bestMatch(
            for: initialSourceFrame,
            edge: edge,
            candidates: geometryCandidates
        ),
              let neighbor = candidates.first(where: { $0.cgWindowID == match.windowID })
        else {
            didFailToCreateSession = true
            return
        }

        session = Session(
            sourceWindowID: source.cgWindowID,
            match: match,
            neighbor: neighbor,
            neighborProperties: Window.ResolvedProperties(from: neighbor)
        )

        log.info("Started adjacent resize with source \(source.cgWindowID) and neighbor \(neighbor.cgWindowID)")
    }

    private func apply(_ frame: CGRect, to session: Session) {
        guard !session.neighbor.frame.approximatelyEqual(to: frame, tolerance: 1) else {
            return
        }

        let sizeFirst = session.match.edge == .right
        session.neighbor.setFrameSynchronously(
            frame,
            sizeFirst: sizeFirst,
            resolvedProperties: session.neighborProperties
        )
    }
}
