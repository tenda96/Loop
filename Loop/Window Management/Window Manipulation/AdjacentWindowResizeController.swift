//
//  AdjacentWindowResizeController.swift
//  Loop
//
//  Created by Codex on 2026-09-11.
//

import AppKit
import Scribe

/// Coordinates one neighboring window with a native resize performed by the user.
///
/// A session is created only after `WindowDragManager` has confirmed that the source window is
/// changing one edge. Candidate discovery happens once per mouse drag; later
/// events reuse the captured frames to avoid repeated WindowServer and Accessibility enumeration.
@Loggable
@MainActor
final class AdjacentWindowResizeController {
    private struct NeighborSession {
        let match: AdjacentWindowResizeGeometry.Match
        let window: Window
        let properties: Window.ResolvedProperties
        var effectiveMinimumSize = AdjacentWindowResizeGeometry.fallbackMinimumWindowSize
    }

    private struct Session {
        let sourceWindowID: CGWindowID
        let edge: AdjacentWindowResizeEdge
        var neighbors: [NeighborSession]
    }

    private var session: Session?
    private var sessionCreationAttempts = 0
    private let maximumSessionCreationAttempts = 5

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
        if session == nil, sessionCreationAttempts < maximumSessionCreationAttempts {
            createSession(
                source: source,
                initialSourceFrame: initialSourceFrame,
                currentSourceFrame: currentSourceFrame
            )
        }

        guard var activeSession = session,
              activeSession.sourceWindowID == source.cgWindowID
        else {
            return
        }

        var resolvedFrames: [AdjacentWindowResizeGeometry.FramePair?] = Array(
            repeating: nil,
            count: activeSession.neighbors.count
        )

        for index in activeSession.neighbors.indices {
            var neighbor = activeSession.neighbors[index]
            guard let frames = AdjacentWindowResizeGeometry.resolvedFrames(
                for: currentSourceFrame,
                match: neighbor.match,
                neighborMinimumSize: neighbor.effectiveMinimumSize
            ) else {
                continue
            }

            apply(frames.neighbor, to: neighbor)

            // Applications enforce their own minimum size after an AX write. Read the result and
            // retain the real constraint so every member of a stacked group shares one boundary.
            let appliedFrame = neighbor.window.frame
            let observedSize = size(of: appliedFrame, for: activeSession.edge)
            let requestedSize = size(of: frames.neighbor, for: activeSession.edge)
            if observedSize > requestedSize + 1 {
                neighbor.effectiveMinimumSize = max(neighbor.effectiveMinimumSize, observedSize)
                activeSession.neighbors[index] = neighbor
            }

            resolvedFrames[index] = AdjacentWindowResizeGeometry.resolvedFrames(
                for: currentSourceFrame,
                match: neighbor.match,
                neighborMinimumSize: neighbor.effectiveMinimumSize
            )
        }

        session = activeSession
        let correctedSources = resolvedFrames.compactMap { $0?.source }

        guard let firstCorrectedSource = correctedSources.first else {
            return
        }
        let finalSourceFrame = correctedSources.dropFirst().reduce(firstCorrectedSource) {
            moreRestrictive($0, $1, edge: activeSession.edge)
        }

        for neighbor in activeSession.neighbors {
            if let correctedFrames = AdjacentWindowResizeGeometry.resolvedFrames(
                for: finalSourceFrame,
                match: neighbor.match,
                neighborMinimumSize: neighbor.effectiveMinimumSize
            ) {
                apply(correctedFrames.neighbor, to: neighbor)
            }
        }

        if !source.frame.approximatelyEqual(to: finalSourceFrame, tolerance: 1) {
            source.setFrameSynchronously(finalSourceFrame)
        }
    }

    /// Clears all state at mouse-up or when drag monitoring shuts down.
    func reset() {
        session = nil
        sessionCreationAttempts = 0
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
              let edge = AdjacentWindowResizeGeometry.resizedEdge(
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

        let configuredGap = PaddingConfiguration.getConfiguredPadding(for: sourceScreen).window
        let matches = AdjacentWindowResizeGeometry.bestMatches(
            for: initialSourceFrame,
            edge: edge,
            candidates: geometryCandidates,
            maximumGap: max(AdjacentWindowResizeGeometry.defaultMaximumGap, configuredGap + 4)
        )

        let neighbors = matches.compactMap { match -> NeighborSession? in
            guard let window = candidates.first(where: { $0.cgWindowID == match.windowID }) else {
                return nil
            }

            return NeighborSession(
                match: match,
                window: window,
                properties: Window.ResolvedProperties(from: window)
            )
        }

        guard !neighbors.isEmpty else {
            sessionCreationAttempts += 1
            return
        }

        session = Session(
            sourceWindowID: source.cgWindowID,
            edge: edge,
            neighbors: neighbors
        )

        let neighborIDs = neighbors.map { String($0.window.cgWindowID) }.joined(separator: ", ")
        log.info("Started adjacent resize with source \(source.cgWindowID) and neighbors [\(neighborIDs)]")
    }

    private func apply(_ frame: CGRect, to neighbor: NeighborSession) {
        guard !neighbor.window.frame.approximatelyEqual(to: frame, tolerance: 1) else {
            return
        }

        let sizeFirst = neighbor.match.edge == .right || neighbor.match.edge == .bottom
        neighbor.window.setFrameSynchronously(
            frame,
            sizeFirst: sizeFirst,
            resolvedProperties: neighbor.properties
        )
    }

    private func size(of frame: CGRect, for edge: AdjacentWindowResizeEdge) -> CGFloat {
        switch edge {
        case .left, .right: frame.width
        case .top, .bottom: frame.height
        }
    }

    private func moreRestrictive(
        _ lhs: CGRect,
        _ rhs: CGRect,
        edge: AdjacentWindowResizeEdge
    ) -> CGRect {
        switch edge {
        case .right:
            lhs.maxX <= rhs.maxX ? lhs : rhs
        case .left:
            lhs.minX >= rhs.minX ? lhs : rhs
        case .bottom:
            lhs.maxY <= rhs.maxY ? lhs : rhs
        case .top:
            lhs.minY >= rhs.minY ? lhs : rhs
        }
    }
}
