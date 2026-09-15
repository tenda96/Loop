//
//  AdjacentWindowResizeGeometryTests.swift
//  LoopTests
//
//  Created by Codex on 2026-09-11.
//

import CoreGraphics
@testable import Loop
import Testing

struct AdjacentWindowResizeGeometryTests {
    @Test func detectsTheMovingRightEdge() {
        let initial = CGRect(x: 0, y: 0, width: 500, height: 700)
        let resized = CGRect(x: 0, y: 0, width: 560, height: 700)

        #expect(
            AdjacentWindowResizeGeometry.resizedHorizontalEdge(from: initial, to: resized) == .right
        )
    }

    @Test func detectsTheMovingLeftEdge() {
        let initial = CGRect(x: 510, y: 0, width: 500, height: 700)
        let resized = CGRect(x: 450, y: 0, width: 560, height: 700)

        #expect(
            AdjacentWindowResizeGeometry.resizedHorizontalEdge(from: initial, to: resized) == .left
        )
    }

    @Test func rejectsMovesAndCornerResizes() {
        let initial = CGRect(x: 0, y: 0, width: 500, height: 700)
        let moved = CGRect(x: 20, y: 10, width: 500, height: 700)
        let cornerResize = CGRect(x: 0, y: 0, width: 560, height: 760)

        #expect(AdjacentWindowResizeGeometry.resizedHorizontalEdge(from: initial, to: moved) == nil)
        #expect(AdjacentWindowResizeGeometry.resizedHorizontalEdge(from: initial, to: cornerResize) == nil)
    }

    @Test func choosesTheClosestAlignedWindowAndPreservesItsGap() throws {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let closest = AdjacentWindowResizeGeometry.Candidate(
            windowID: 2,
            frame: CGRect(x: 510, y: 0, width: 500, height: 700)
        )
        let farther = AdjacentWindowResizeGeometry.Candidate(
            windowID: 3,
            frame: CGRect(x: 525, y: 0, width: 500, height: 700)
        )
        let verticallyUnrelated = AdjacentWindowResizeGeometry.Candidate(
            windowID: 4,
            frame: CGRect(x: 505, y: 690, width: 500, height: 700)
        )

        let match = try #require(
            AdjacentWindowResizeGeometry.bestMatch(
                for: source,
                edge: .right,
                candidates: [farther, verticallyUnrelated, closest]
            )
        )

        #expect(match.windowID == closest.windowID)
        #expect(match.gap == 10)
    }

    @Test func rejectsWindowsOutsideTheMaximumGap() {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let candidate = AdjacentWindowResizeGeometry.Candidate(
            windowID: 2,
            frame: CGRect(x: 540, y: 0, width: 500, height: 700)
        )

        let match = AdjacentWindowResizeGeometry.bestMatch(
            for: source,
            edge: .right,
            candidates: [candidate]
        )

        #expect(match == nil)
    }

    @Test func movingTheRightBoundaryKeepsTheGapAndNeighborOuterEdge() throws {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let neighbor = CGRect(x: 510, y: 0, width: 500, height: 700)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 2,
            edge: .right,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )

        let frames = try #require(
            AdjacentWindowResizeGeometry.resolvedFrames(
                for: CGRect(x: 0, y: 0, width: 600, height: 700),
                match: match
            )
        )

        #expect(frames.source.maxX == 600)
        #expect(frames.neighbor.minX == 610)
        #expect(frames.neighbor.maxX == neighbor.maxX)
    }

    @Test func movingTheLeftBoundaryKeepsTheGapAndNeighborOuterEdge() throws {
        let neighbor = CGRect(x: 0, y: 0, width: 500, height: 700)
        let source = CGRect(x: 510, y: 0, width: 500, height: 700)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 1,
            edge: .left,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )

        let frames = try #require(
            AdjacentWindowResizeGeometry.resolvedFrames(
                for: CGRect(x: 610, y: 0, width: 400, height: 700),
                match: match
            )
        )

        #expect(frames.source.minX == 610)
        #expect(frames.source.maxX == source.maxX)
        #expect(frames.neighbor.maxX == 600)
        #expect(frames.neighbor.minX == neighbor.minX)
    }

    @Test func minimumNeighborWidthClampsTheSourceAtTheSharedBoundary() throws {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let neighbor = CGRect(x: 510, y: 0, width: 500, height: 700)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 2,
            edge: .right,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )

        let frames = try #require(
            AdjacentWindowResizeGeometry.resolvedFrames(
                for: CGRect(x: 0, y: 0, width: 900, height: 700),
                match: match,
                neighborMinimumWidth: 300
            )
        )

        #expect(frames.source.maxX == 700)
        #expect(frames.neighbor.minX == 710)
        #expect(frames.neighbor.width == 300)
    }
}
