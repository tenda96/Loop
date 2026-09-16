//
//  AdjacentWindowResizeGeometry.swift
//  Loop
//
//  Created by Codex on 2026-09-11.
//

import CoreGraphics

/// Describes the edge of a source window that is being resized.
enum AdjacentWindowResizeEdge: Equatable {
    case left
    case right
    case top
    case bottom
}

/// Pure geometry used to identify and resize a window adjacent to any shared edge.
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

    /// A pair of frames that shares one boundary while preserving both outer edges.
    struct FramePair: Equatable {
        let source: CGRect
        let neighbor: CGRect
    }

    /// The small overlap allowance accounts for borders and AX frame rounding between applications.
    static let defaultOverlapAllowance: CGFloat = 2

    /// Windows farther apart than this value are not considered part of the same layout.
    static let defaultMaximumGap: CGFloat = 32

    /// Require meaningful alignment on the shared edge so unrelated nearby windows are ignored.
    static let defaultMinimumPerpendicularOverlapRatio: CGFloat = 0.5

    /// A generic safety floor for applications that do not expose a usable minimum size.
    static let fallbackMinimumWindowSize: CGFloat = 80

    /// Infers which single edge changed during a native macOS resize.
    /// - Parameters:
    ///   - initialFrame: Source frame captured near the beginning of the drag.
    ///   - currentFrame: Most recently observed source frame.
    ///   - tolerance: Maximum AX rounding drift accepted on an edge that should be stationary.
    /// - Returns: The moving edge, or `nil` for moves and corner resizes.
    static func resizedEdge(
        from initialFrame: CGRect,
        to currentFrame: CGRect,
        tolerance: CGFloat = 1.5
    ) -> AdjacentWindowResizeEdge? {
        let changedEdges: [AdjacentWindowResizeEdge] = [
            abs(currentFrame.minX - initialFrame.minX) > tolerance ? .left : nil,
            abs(currentFrame.maxX - initialFrame.maxX) > tolerance ? .right : nil,
            abs(currentFrame.minY - initialFrame.minY) > tolerance ? .top : nil,
            abs(currentFrame.maxY - initialFrame.maxY) > tolerance ? .bottom : nil
        ].compactMap { $0 }

        return changedEdges.count == 1 ? changedEdges[0] : nil
    }

    /// Finds the closest candidate sharing enough perpendicular space with the source window.
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
        minimumPerpendicularOverlapRatio: CGFloat = defaultMinimumPerpendicularOverlapRatio
    ) -> Match? {
        let eligible = candidates.compactMap { candidate -> (candidate: Candidate, gap: CGFloat, overlap: CGFloat)? in
            let gap = gap(from: sourceFrame, to: candidate.frame, edge: edge)
            guard gap >= -overlapAllowance, gap <= maximumGap else {
                return nil
            }

            let overlap = perpendicularOverlap(sourceFrame, candidate.frame, edge: edge)
            let shorterSpan = perpendicularSpan(sourceFrame, candidate.frame, edge: edge)
            guard shorterSpan > 0,
                  overlap / shorterSpan >= minimumPerpendicularOverlapRatio
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
    ///   - neighborMinimumSize: Minimum usable width or height for the neighboring window.
    /// - Returns: Coordinated source and neighbor frames, or `nil` if the geometry is invalid.
    static func resolvedFrames(
        for currentSourceFrame: CGRect,
        match: Match,
        neighborMinimumSize: CGFloat = fallbackMinimumWindowSize
    ) -> FramePair? {
        let minimumSize = max(1, neighborMinimumSize)
        var source = match.initialSourceFrame
        var neighbor = match.initialNeighborFrame

        switch match.edge {
        case .right:
            let neighborOuterEdge = match.initialNeighborFrame.maxX
            let maximumSharedEdge = neighborOuterEdge - minimumSize - match.gap
            let sharedEdge = min(currentSourceFrame.maxX, maximumSharedEdge)

            source.size.width = sharedEdge - source.minX
            neighbor.origin.x = sharedEdge + match.gap
            neighbor.size.width = neighborOuterEdge - neighbor.minX

        case .left:
            let neighborOuterEdge = match.initialNeighborFrame.minX
            let sourceOuterEdge = match.initialSourceFrame.maxX
            let minimumSharedEdge = neighborOuterEdge + minimumSize + match.gap
            let sharedEdge = max(currentSourceFrame.minX, minimumSharedEdge)

            source.origin.x = sharedEdge
            source.size.width = sourceOuterEdge - sharedEdge
            neighbor.origin.x = neighborOuterEdge
            neighbor.size.width = sharedEdge - match.gap - neighborOuterEdge

        case .bottom:
            let neighborOuterEdge = match.initialNeighborFrame.maxY
            let maximumSharedEdge = neighborOuterEdge - minimumSize - match.gap
            let sharedEdge = min(currentSourceFrame.maxY, maximumSharedEdge)

            source.size.height = sharedEdge - source.minY
            neighbor.origin.y = sharedEdge + match.gap
            neighbor.size.height = neighborOuterEdge - neighbor.minY

        case .top:
            let neighborOuterEdge = match.initialNeighborFrame.minY
            let sourceOuterEdge = match.initialSourceFrame.maxY
            let minimumSharedEdge = neighborOuterEdge + minimumSize + match.gap
            let sharedEdge = max(currentSourceFrame.minY, minimumSharedEdge)

            source.origin.y = sharedEdge
            source.size.height = sourceOuterEdge - sharedEdge
            neighbor.origin.y = neighborOuterEdge
            neighbor.size.height = sharedEdge - match.gap - neighborOuterEdge
        }

        guard source.width > 0,
              source.height > 0,
              neighbor.width > 0,
              neighbor.height > 0
        else {
            return nil
        }

        return FramePair(source: source, neighbor: neighbor)
    }

    private static func gap(
        from sourceFrame: CGRect,
        to candidateFrame: CGRect,
        edge: AdjacentWindowResizeEdge
    ) -> CGFloat {
        switch edge {
        case .left:
            sourceFrame.minX - candidateFrame.maxX
        case .right:
            candidateFrame.minX - sourceFrame.maxX
        case .top:
            sourceFrame.minY - candidateFrame.maxY
        case .bottom:
            candidateFrame.minY - sourceFrame.maxY
        }
    }

    private static func perpendicularOverlap(
        _ lhs: CGRect,
        _ rhs: CGRect,
        edge: AdjacentWindowResizeEdge
    ) -> CGFloat {
        switch edge {
        case .left, .right:
            max(0, min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY))
        case .top, .bottom:
            max(0, min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX))
        }
    }

    private static func perpendicularSpan(
        _ lhs: CGRect,
        _ rhs: CGRect,
        edge: AdjacentWindowResizeEdge
    ) -> CGFloat {
        switch edge {
        case .left, .right:
            min(lhs.height, rhs.height)
        case .top, .bottom:
            min(lhs.width, rhs.width)
        }
    }
}
