//
//  AdjacentWindowResizeGeometry.swift
//  Loop
//
//  Created by Codex on 2026-09-11.
//

import CoreGraphics

/// Describes the vertical edge of a source window that is being resized.
enum AdjacentWindowResizeEdge: Equatable {
    case left
    case right
}

/// Pure geometry used to identify and resize a horizontally adjacent window.
///
/// Keeping these calculations independent from Accessibility makes the behavior deterministic
/// and allows the edge cases to be covered without manipulating real application windows.
enum AdjacentWindowResizeGeometry {
    /// A lightweight snapshot used while choosing an adjacent window.
    struct Candidate: Equatable {
        let windowID: CGWindowID
        let frame: CGRect
    }

    /// The immutable geometry captured when an adjacent resize session starts.
    struct Match: Equatable {
        let windowID: CGWindowID
        let edge: AdjacentWindowResizeEdge
        let initialSourceFrame: CGRect
        let initialNeighborFrame: CGRect
        let gap: CGFloat
    }

    /// A pair of frames that shares one vertical boundary while preserving both outer edges.
    struct FramePair: Equatable {
        let source: CGRect
        let neighbor: CGRect
    }

    /// The small overlap allowance accounts for borders and AX frame rounding between applications.
    static let defaultOverlapAllowance: CGFloat = 2

    /// Windows farther apart than this value are not considered part of the same layout.
    static let defaultMaximumGap: CGFloat = 32

    /// Require meaningful vertical alignment so unrelated nearby windows are ignored.
    static let defaultMinimumVerticalOverlapRatio: CGFloat = 0.5

    /// A generic safety floor for applications that do not expose a usable minimum width.
    static let fallbackMinimumWindowWidth: CGFloat = 80

    /// Infers which horizontal edge changed during a native macOS resize.
    /// - Parameters:
    ///   - initialFrame: Source frame captured near the beginning of the drag.
    ///   - currentFrame: Most recently observed source frame.
    ///   - tolerance: Maximum AX rounding drift accepted on an edge that should be stationary.
    /// - Returns: The moving vertical edge, or `nil` for moves, corner resizes, and vertical resizes.
    static func resizedHorizontalEdge(
        from initialFrame: CGRect,
        to currentFrame: CGRect,
        tolerance: CGFloat = 1.5
    ) -> AdjacentWindowResizeEdge? {
        let widthChanged = abs(currentFrame.width - initialFrame.width) > tolerance
        let heightStayedFixed = abs(currentFrame.height - initialFrame.height) <= tolerance

        guard widthChanged, heightStayedFixed else {
            return nil
        }

        let leftStayedFixed = abs(currentFrame.minX - initialFrame.minX) <= tolerance
        let rightStayedFixed = abs(currentFrame.maxX - initialFrame.maxX) <= tolerance

        if leftStayedFixed, !rightStayedFixed {
            return .right
        }

        if rightStayedFixed, !leftStayedFixed {
            return .left
        }

        return nil
    }

    /// Finds the closest candidate sharing enough vertical space with the source window.
    /// - Parameters:
    ///   - sourceFrame: Source frame at the start of the resize session.
    ///   - edge: Source edge being dragged.
    ///   - candidates: Already-filtered, same-display visible windows.
    ///   - maximumGap: Largest permitted distance between the two facing edges.
    ///   - overlapAllowance: Small permitted overlap for border and rounding differences.
    ///   - minimumVerticalOverlapRatio: Required overlap relative to the shorter window.
    /// - Returns: A stable match containing the original gap and both initial frames.
    static func bestMatch(
        for sourceFrame: CGRect,
        edge: AdjacentWindowResizeEdge,
        candidates: [Candidate],
        maximumGap: CGFloat = defaultMaximumGap,
        overlapAllowance: CGFloat = defaultOverlapAllowance,
        minimumVerticalOverlapRatio: CGFloat = defaultMinimumVerticalOverlapRatio
    ) -> Match? {
        let eligible = candidates.compactMap { candidate -> (candidate: Candidate, gap: CGFloat, overlap: CGFloat)? in
            let gap = horizontalGap(from: sourceFrame, to: candidate.frame, edge: edge)
            guard gap >= -overlapAllowance, gap <= maximumGap else {
                return nil
            }

            let overlap = verticalOverlap(sourceFrame, candidate.frame)
            let shorterHeight = min(sourceFrame.height, candidate.frame.height)
            guard shorterHeight > 0,
                  overlap / shorterHeight >= minimumVerticalOverlapRatio
            else {
                return nil
            }

            return (candidate, gap, overlap)
        }

        guard let best = eligible.min(by: { lhs, rhs in
            let lhsDistance = abs(lhs.gap)
            let rhsDistance = abs(rhs.gap)

            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            if lhs.overlap != rhs.overlap {
                return lhs.overlap > rhs.overlap
            }

            return lhs.candidate.windowID < rhs.candidate.windowID
        }) else {
            return nil
        }

        return Match(
            windowID: best.candidate.windowID,
            edge: edge,
            initialSourceFrame: sourceFrame,
            initialNeighborFrame: best.candidate.frame,
            gap: best.gap
        )
    }

    /// Resolves both frames for the current shared-edge position.
    ///
    /// The source's outer edge, the neighbor's outer edge, and the original gap remain fixed.
    /// If the requested position would make the neighbor too narrow, the shared boundary is clamped
    /// and the source frame is corrected to match it.
    /// - Parameters:
    ///   - currentSourceFrame: Source frame currently produced by the user's native resize.
    ///   - match: Geometry captured when the resize session began.
    ///   - neighborMinimumWidth: Minimum usable width for the neighboring window.
    /// - Returns: Coordinated source and neighbor frames, or `nil` if the geometry is invalid.
    static func resolvedFrames(
        for currentSourceFrame: CGRect,
        match: Match,
        neighborMinimumWidth: CGFloat = fallbackMinimumWindowWidth
    ) -> FramePair? {
        let minimumWidth = max(1, neighborMinimumWidth)
        var source = match.initialSourceFrame
        var neighbor = match.initialNeighborFrame

        switch match.edge {
        case .right:
            let neighborOuterEdge = match.initialNeighborFrame.maxX
            let maximumSharedEdge = neighborOuterEdge - minimumWidth - match.gap
            let sharedEdge = min(currentSourceFrame.maxX, maximumSharedEdge)

            source.size.width = sharedEdge - source.minX
            neighbor.origin.x = sharedEdge + match.gap
            neighbor.size.width = neighborOuterEdge - neighbor.minX

        case .left:
            let neighborOuterEdge = match.initialNeighborFrame.minX
            let sourceOuterEdge = match.initialSourceFrame.maxX
            let minimumSharedEdge = neighborOuterEdge + minimumWidth + match.gap
            let sharedEdge = max(currentSourceFrame.minX, minimumSharedEdge)

            source.origin.x = sharedEdge
            source.size.width = sourceOuterEdge - sharedEdge
            neighbor.origin.x = neighborOuterEdge
            neighbor.size.width = sharedEdge - match.gap - neighborOuterEdge
        }

        guard source.width > 0, neighbor.width > 0 else {
            return nil
        }

        return FramePair(source: source, neighbor: neighbor)
    }

    private static func horizontalGap(
        from sourceFrame: CGRect,
        to candidateFrame: CGRect,
        edge: AdjacentWindowResizeEdge
    ) -> CGFloat {
        switch edge {
        case .left:
            sourceFrame.minX - candidateFrame.maxX
        case .right:
            candidateFrame.minX - sourceFrame.maxX
        }
    }

    private static func verticalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        max(0, min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY))
    }
}
