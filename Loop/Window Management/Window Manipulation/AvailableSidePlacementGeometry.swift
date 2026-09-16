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

    enum Resolution: Equatable {
        case available(CGRect)
        case noLayout
        case blocked
    }

    struct Candidate: Equatable {
        let windowID: CGWindowID
        let frame: CGRect
    }

    static let minimumWindowWidth: CGFloat = 160
    static let minimumWindowHeight: CGFloat = 120
    static let minimumScreenHeightCoverage: CGFloat = 0.6
    static let sharedBoundaryTolerance: CGFloat = 2

    static func targetFrame(
        for side: Side,
        in bounds: CGRect,
        candidates: [Candidate],
        windowGap: CGFloat = 0
    ) -> CGRect? {
        guard case let .available(frame) = resolution(
            for: side,
            in: bounds,
            candidates: candidates,
            windowGap: windowGap
        ) else {
            return nil
        }
        return frame
    }

    /// Distinguishes a layout that cannot be inferred from one whose destination is fully occupied.
    /// Callers can use the latter to keep the source window in place instead of falling back to a
    /// standard half-screen frame that would overlap another visible window.
    static func resolution(
        for side: Side,
        in bounds: CGRect,
        candidates: [Candidate],
        windowGap: CGFloat = 0
    ) -> Resolution {
        guard bounds.width >= minimumWindowWidth * 2, bounds.height > 0 else {
            return .noLayout
        }

        let possibleObstacles = candidates.compactMap { candidate -> (Candidate, CGRect, CGFloat)? in
            let frame = candidate.frame.intersection(bounds)
            guard !frame.isNull else {
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
                return (candidate, frame, frame.maxX)
            case .left:
                guard frame.midX > bounds.midX,
                      frame.minX < bounds.maxX,
                      frame.minX - bounds.minX - windowGap >= minimumWindowWidth
                else {
                    return nil
                }
                return (candidate, frame, frame.minX)
            }
        }

        var boundaryGroups: [[(Candidate, CGRect, CGFloat)]] = []
        for obstacle in possibleObstacles {
            if let index = boundaryGroups.firstIndex(where: {
                guard let boundary = $0.first?.2 else {
                    return false
                }
                return abs(boundary - obstacle.2) <= sharedBoundaryTolerance
            }) {
                boundaryGroups[index].append(obstacle)
            } else {
                boundaryGroups.append([obstacle])
            }
        }

        let eligibleGroups = boundaryGroups.filter {
            verticalCoverage(of: $0.map(\.1), in: bounds) / bounds.height >= minimumScreenHeightCoverage
        }

        let selectedGroup: [(Candidate, CGRect, CGFloat)]? = switch side {
        case .right:
            eligibleGroups.max { ($0.first?.2 ?? -.infinity) < ($1.first?.2 ?? -.infinity) }
        case .left:
            eligibleGroups.min { ($0.first?.2 ?? .infinity) < ($1.first?.2 ?? .infinity) }
        }

        guard let selectedGroup,
              let sharedBoundary = selectedGroup.first?.2
        else {
            return .noLayout
        }

        let halfGap = max(0, windowGap) / 2
        let fullTarget: CGRect = switch side {
        case .right:
            CGRect(
                x: sharedBoundary + halfGap,
                y: bounds.minY,
                width: bounds.maxX - sharedBoundary - halfGap,
                height: bounds.height
            )
        case .left:
            CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: sharedBoundary - halfGap - bounds.minX,
                height: bounds.height
            )
        }

        let selectedIDs = Set(selectedGroup.map(\.0.windowID))
        let blockers = candidates.compactMap { candidate -> CGRect? in
            guard !selectedIDs.contains(candidate.windowID) else {
                return nil
            }
            let intersection = candidate.frame.intersection(fullTarget)
            return intersection.width > 1 && intersection.height > 1 ? intersection : nil
        }

        guard let availableFrame = largestFreeVerticalSlice(in: fullTarget, avoiding: blockers) else {
            return .blocked
        }
        return .available(availableFrame)
    }

    private static func verticalCoverage(of frames: [CGRect], in bounds: CGRect) -> CGFloat {
        let intervals = frames
            .map { (max(bounds.minY, $0.minY), min(bounds.maxY, $0.maxY)) }
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }

        var total: CGFloat = 0
        var active: (min: CGFloat, max: CGFloat)?
        for interval in intervals {
            guard let current = active else {
                active = interval
                continue
            }

            if interval.0 <= current.max {
                active = (current.min, max(current.max, interval.1))
            } else {
                total += current.max - current.min
                active = interval
            }
        }

        if let active {
            total += active.max - active.min
        }
        return total
    }

    private static func largestFreeVerticalSlice(
        in target: CGRect,
        avoiding blockers: [CGRect]
    ) -> CGRect? {
        guard !target.isNull,
              target.width >= minimumWindowWidth,
              target.height >= minimumWindowHeight
        else {
            return nil
        }

        guard !blockers.isEmpty else {
            return target
        }

        let boundaries = Set(
            [target.minY, target.maxY] + blockers.flatMap { [$0.minY, $0.maxY] }
        ).sorted()

        var best: CGRect?
        for lowerIndex in boundaries.indices {
            for upperIndex in boundaries.indices where upperIndex > lowerIndex {
                let minY = boundaries[lowerIndex]
                let maxY = boundaries[upperIndex]
                let candidate = CGRect(
                    x: target.minX,
                    y: minY,
                    width: target.width,
                    height: maxY - minY
                ).intersection(target)

                guard candidate.height >= minimumWindowHeight,
                      blockers.allSatisfy({ !$0.intersects(candidate.insetBy(dx: 1, dy: 1)) })
                else {
                    continue
                }

                let candidateArea = candidate.width * candidate.height
                let bestArea = best.map { $0.width * $0.height } ?? 0
                if candidateArea > bestArea {
                    best = candidate
                }
            }
        }

        return best
    }
}
