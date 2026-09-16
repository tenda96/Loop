//
//  AvailableSidePlacementGeometry.swift
//  Loop
//
//  Created by Codex on 2026-09-15.
//

import CoreGraphics

/// Resolves a left/right placement against a window that already occupies the opposite side.
enum AvailableSidePlacementGeometry {
    enum Side {
        case left
        case right
    }

    struct Candidate: Equatable {
        let windowID: CGWindowID
        let frame: CGRect
    }

    static let minimumWindowWidth: CGFloat = 160
    static let minimumScreenHeightCoverage: CGFloat = 0.6

    static func targetFrame(
        for side: Side,
        in bounds: CGRect,
        candidates: [Candidate],
        windowGap: CGFloat = 0
    ) -> CGRect? {
        guard bounds.width >= minimumWindowWidth * 2, bounds.height > 0 else {
            return nil
        }

        let eligible = candidates.compactMap { candidate -> (Candidate, CGRect)? in
            let frame = candidate.frame.intersection(bounds)
            guard !frame.isNull,
                  frame.height / bounds.height >= minimumScreenHeightCoverage
            else {
                return nil
            }

            switch side {
            case .right:
                guard frame.midX < bounds.midX,
                      frame.maxX > bounds.minX,
                      bounds.maxX - frame.maxX - windowGap >= minimumWindowWidth
                else {
                    return nil
                }
            case .left:
                guard frame.midX > bounds.midX,
                      frame.minX < bounds.maxX,
                      frame.minX - bounds.minX - windowGap >= minimumWindowWidth
                else {
                    return nil
                }
            }

            return (candidate, frame)
        }

        let selected: (Candidate, CGRect)? = switch side {
        case .right:
            eligible.max { lhs, rhs in
                if lhs.1.maxX != rhs.1.maxX {
                    return lhs.1.maxX < rhs.1.maxX
                }
                return lhs.0.windowID > rhs.0.windowID
            }
        case .left:
            eligible.min { lhs, rhs in
                if lhs.1.minX != rhs.1.minX {
                    return lhs.1.minX < rhs.1.minX
                }
                return lhs.0.windowID < rhs.0.windowID
            }
        }

        guard let obstacle = selected?.1 else {
            return nil
        }

        let halfGap = max(0, windowGap) / 2
        switch side {
        case .right:
            let minX = obstacle.maxX + halfGap
            return CGRect(x: minX, y: bounds.minY, width: bounds.maxX - minX, height: bounds.height)
        case .left:
            let maxX = obstacle.minX - halfGap
            return CGRect(x: bounds.minX, y: bounds.minY, width: maxX - bounds.minX, height: bounds.height)
        }
    }
}
