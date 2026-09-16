import CoreGraphics

@main
enum AdjacentWindowResizeGeometrySmoke {
    static func main() {
        detectsMovingEdges()
        choosesClosestAlignedNeighbor()
        preservesRightSharedBoundary()
        preservesLeftSharedBoundary()
        preservesBottomSharedBoundary()
        clampsNeighborMinimumWidth()
        fillsAvailableRightSide()

        print("Adjacent window resize geometry checks passed.")
    }

    private static func detectsMovingEdges() {
        let leftWindow = CGRect(x: 0, y: 0, width: 500, height: 700)
        let rightWindow = CGRect(x: 510, y: 0, width: 500, height: 700)

        expect(
            AdjacentWindowResizeGeometry.resizedEdge(
                from: leftWindow,
                to: CGRect(x: 0, y: 0, width: 560, height: 700)
            ) == .right,
            "The moving right edge was not detected."
        )
        expect(
            AdjacentWindowResizeGeometry.resizedEdge(
                from: rightWindow,
                to: CGRect(x: 450, y: 0, width: 560, height: 700)
            ) == .left,
            "The moving left edge was not detected."
        )
        expect(
            AdjacentWindowResizeGeometry.resizedEdge(
                from: leftWindow,
                to: CGRect(x: 0, y: 0, width: 500, height: 760)
            ) == .bottom,
            "The moving bottom edge was not detected."
        )
        expect(
            AdjacentWindowResizeGeometry.resizedEdge(
                from: leftWindow,
                to: CGRect(x: 20, y: 10, width: 500, height: 700)
            ) == nil,
            "A window move was incorrectly classified as a resize."
        )
    }

    private static func choosesClosestAlignedNeighbor() {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let candidates = [
            AdjacentWindowResizeGeometry.Candidate(
                windowID: 3,
                frame: CGRect(x: 525, y: 0, width: 500, height: 700)
            ),
            AdjacentWindowResizeGeometry.Candidate(
                windowID: 4,
                frame: CGRect(x: 505, y: 690, width: 500, height: 700)
            ),
            AdjacentWindowResizeGeometry.Candidate(
                windowID: 2,
                frame: CGRect(x: 510, y: 0, width: 500, height: 700)
            )
        ]
        let match = AdjacentWindowResizeGeometry.bestMatch(
            for: source,
            edge: .right,
            candidates: candidates
        )

        expect(match?.windowID == 2, "The closest aligned neighbor was not selected.")
        expect(match?.gap == 10, "The original window gap was not captured.")
    }

    private static func preservesRightSharedBoundary() {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let neighbor = CGRect(x: 510, y: 0, width: 500, height: 700)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 2,
            edge: .right,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )
        let frames = AdjacentWindowResizeGeometry.resolvedFrames(
            for: CGRect(x: 0, y: 0, width: 600, height: 700),
            match: match
        )

        expect(frames?.source.maxX == 600, "The source right edge was not preserved.")
        expect(frames?.neighbor.minX == 610, "The neighbor did not follow the shared edge.")
        expect(frames?.neighbor.maxX == neighbor.maxX, "The neighbor outer edge moved.")
    }

    private static func preservesLeftSharedBoundary() {
        let neighbor = CGRect(x: 0, y: 0, width: 500, height: 700)
        let source = CGRect(x: 510, y: 0, width: 500, height: 700)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 1,
            edge: .left,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )
        let frames = AdjacentWindowResizeGeometry.resolvedFrames(
            for: CGRect(x: 610, y: 0, width: 400, height: 700),
            match: match
        )

        expect(frames?.source.minX == 610, "The source left edge was not preserved.")
        expect(frames?.source.maxX == source.maxX, "The source outer edge moved.")
        expect(frames?.neighbor.maxX == 600, "The neighbor did not follow the shared edge.")
        expect(frames?.neighbor.minX == neighbor.minX, "The neighbor outer edge moved.")
    }

    private static func clampsNeighborMinimumWidth() {
        let source = CGRect(x: 0, y: 0, width: 500, height: 700)
        let neighbor = CGRect(x: 510, y: 0, width: 500, height: 700)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 2,
            edge: .right,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )
        let frames = AdjacentWindowResizeGeometry.resolvedFrames(
            for: CGRect(x: 0, y: 0, width: 900, height: 700),
            match: match,
            neighborMinimumSize: 300
        )

        expect(frames?.source.maxX == 700, "The shared edge ignored the minimum width.")
        expect(frames?.neighbor.width == 300, "The neighbor minimum width was not applied.")
    }

    private static func preservesBottomSharedBoundary() {
        let source = CGRect(x: 0, y: 0, width: 900, height: 400)
        let neighbor = CGRect(x: 0, y: 410, width: 900, height: 390)
        let match = AdjacentWindowResizeGeometry.Match(
            windowID: 2,
            edge: .bottom,
            initialSourceFrame: source,
            initialNeighborFrame: neighbor,
            gap: 10
        )
        let frames = AdjacentWindowResizeGeometry.resolvedFrames(
            for: CGRect(x: 0, y: 0, width: 900, height: 500),
            match: match
        )

        expect(frames?.neighbor.minY == 510, "The lower neighbor did not follow the shared edge.")
        expect(frames?.neighbor.maxY == neighbor.maxY, "The lower neighbor outer edge moved.")
    }

    private static func fillsAvailableRightSide() {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let frame = AvailableSidePlacementGeometry.targetFrame(
            for: .right,
            in: bounds,
            candidates: [
                .init(windowID: 2, frame: CGRect(x: 0, y: 0, width: 450, height: 800))
            ],
            windowGap: 10
        )

        expect(frame?.minX == 455, "Right placement ignored the existing left window.")
        expect(frame?.maxX == bounds.maxX, "Right placement did not reach the screen edge.")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            fatalError(message)
        }
    }
}
