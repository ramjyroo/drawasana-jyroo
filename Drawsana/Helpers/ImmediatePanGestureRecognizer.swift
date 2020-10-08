//
//  ImmediatePanGestureRecognizer.swift
//  Drawsana
//
//  Created by Steve Landey on 8/14/18.
//  Copyright © 2018 Asana. All rights reserved.
//

import UIKit

/**
 Replaces a tap gesture recognizer and a pan gesture recognizer with just one
 gesture recognizer.

 Lifecycle:
 * Touch begins, state -> .began (all other touches are completely ignored)
 * Touch moves, state -> .changed
 * Touch ends
   * If touch moved more than 10px away from the origin at some point, then
     `hasExceededTapThreshold` was set to `true`. Target may use this to
     distinguish a pan from a tap when the gesture has ended and act
     accordingly.

 This behavior is better than using a regular UIPanGestureRecognizer because
 that class ignores the first ~20px of the touch while it figures out if you
 "really" want to pan. This is a drawing program, so that's not good.
 */
class ImmediatePanGestureRecognizer: UIGestureRecognizer {
  var tapThreshold: CGFloat = 10
  // If gesture ends and this value is `true`, then the user's finger moved
  // more than `tapThreshold` points during the gesture, i.e. it is not a tap.
  private(set) var hasExceededTapThreshold = false

  private var startPoint: CGPoint = .zero
  private var lastLastPoint: CGPoint = .zero
  private var lastLastTime: CFTimeInterval = 0
  private var lastPoint: CGPoint = .zero
  private var lastTime: CFTimeInterval = 0
  private var trackedTouch: UITouch?
  private var didIgnoreToucheEnded: Bool = false
  var velocity: CGPoint? {
    guard let view = view, let trackedTouch = trackedTouch else { return nil }
    let delta = trackedTouch.location(in: view) - lastLastPoint
    let deltaT = CGFloat(lastTime - lastLastTime)
    return CGPoint(x: delta.x / deltaT , y: delta.y - deltaT)
  }

  override func location(in view: UIView?) -> CGPoint {
    guard let view = view else {
      return lastPoint
    }
    return view.convert(lastPoint, to: view)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let view = view else {
        print("touchesBegan - Skip processing as view is nil")
        return
    }
    guard let firstTouch = touches.first else {
        print("touchesBegan - Skip processing as touches is empty - not able to get first touch")
        return
    }
    if let existingTrackedTouch = trackedTouch {
        if didIgnoreToucheEnded {
            print("touchesBegan - Skip processing as trackedTouch is already set - phase: \(existingTrackedTouch.phase), count: \(existingTrackedTouch.tapCount) didIgnoreToucheEnded was set")
            didIgnoreToucheEnded = false
            self.trackedTouch = nil
        } else {
            print("touchesBegan - Skip processing as trackedTouch is already set - phase: \(existingTrackedTouch.phase), count: \(existingTrackedTouch.tapCount) didIgnoreToucheEnded was not set")
            return
        }
    }
    trackedTouch = firstTouch
    startPoint = firstTouch.location(in: view)
    lastPoint = startPoint
    lastTime = CFAbsoluteTimeGetCurrent()
    lastLastPoint = startPoint
    lastLastTime = lastTime
    print("touchesBegan - Updating state from: \(state) to began - set tracked touch - phase: \(firstTouch.phase.rawValue), count: \(firstTouch.tapCount)")
    state = .began
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let view = view else {
        print("touchesMoved -  Skip processing as view is nil")
        return
    }
    guard state == .began || state == .changed else {
        print("touchesMoved -  Skip processing as state: \(state) is not in began or changed state")
        return
    }
    guard let trackedTouch = trackedTouch else {
        print("touchesMoved -  Skip processing as trackedTouch is not set")
        return
    }
    guard touches.contains(trackedTouch) else {
        print("touchesMoved - Skip processing as trackedTouch is not in touches set")
        return
    }
    lastLastTime = lastTime
    lastLastPoint = lastPoint
    lastTime = CFAbsoluteTimeGetCurrent()
    lastPoint = trackedTouch.location(in: view)
    if (lastPoint - startPoint).length >= tapThreshold {
      hasExceededTapThreshold = true
    }
    print("touchesMoved - Updating state from: \(state) to changed")
    state = .changed
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    guard state == .began || state == .changed else {
        print("touchesEnded -  Skip processing as state: \(state) is not in began or changed state")
        return
    }
    guard let trackedTouch = trackedTouch else {
        print("touchesEnded -  Skip processing as trackedTouch is not set")
        return
    }
    guard touches.contains(trackedTouch) else {
        print("touchesEnded - Skip processing as trackedTouch is not in touches set")
        didIgnoreToucheEnded = true
        return
    }
    print("touchesEnded - Updating state from: \(state) to ended")
    state = .ended

    DispatchQueue.main.async {
      self.reset()
    }
  }

  override func reset() {
    super.reset()
    trackedTouch = nil
    hasExceededTapThreshold = false
  }
}
