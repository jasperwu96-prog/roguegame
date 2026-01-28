//
//  VirtualJoystick.swift
//  RogueWave
//
//  Virtual joystick control for touch-based movement
//

import SpriteKit

// MARK: - Joystick Delegate Protocol

protocol VirtualJoystickDelegate: AnyObject {
    func joystickDidMove(direction: CGVector)
    func joystickDidEnd()
}

// MARK: - Virtual Joystick Class

class VirtualJoystick: SKNode {

    // MARK: - Properties

    weak var delegate: VirtualJoystickDelegate?

    // Visual components
    private var baseNode: SKShapeNode!
    private var knobNode: SKShapeNode!

    // Configuration
    private let baseRadius: CGFloat
    private let knobRadius: CGFloat

    // State
    private var isTracking: Bool = false
    private var trackingTouch: UITouch?
    private var initialTouchPosition: CGPoint = .zero

    // Current direction output
    private(set) var currentDirection: CGVector = .zero

    // Joystick behavior
    var isDynamic: Bool = true  // If true, joystick appears at touch location
    var deadzone: CGFloat = 0.1  // Minimum movement threshold (0-1)

    // MARK: - Initialization

    init(baseSize: CGFloat = UIConfig.joystickBaseSize,
         knobSize: CGFloat = UIConfig.joystickKnobSize) {

        self.baseRadius = baseSize / 2
        self.knobRadius = knobSize / 2

        super.init()

        setupVisuals()
        isUserInteractionEnabled = true
        zPosition = GameConfig.ZPosition.ui
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupVisuals() {
        // Joystick base (outer circle)
        baseNode = SKShapeNode(circleOfRadius: baseRadius)
        baseNode.fillColor = SKColor.white.withAlphaComponent(0.15)
        baseNode.strokeColor = SKColor.white.withAlphaComponent(0.4)
        baseNode.lineWidth = 3
        addChild(baseNode)

        // Inner ring decoration
        let innerRing = SKShapeNode(circleOfRadius: baseRadius * 0.6)
        innerRing.fillColor = .clear
        innerRing.strokeColor = SKColor.white.withAlphaComponent(0.2)
        innerRing.lineWidth = 1
        baseNode.addChild(innerRing)

        // Joystick knob (inner circle)
        knobNode = SKShapeNode(circleOfRadius: knobRadius)
        knobNode.fillColor = SKColor.white.withAlphaComponent(0.6)
        knobNode.strokeColor = SKColor.white.withAlphaComponent(0.8)
        knobNode.lineWidth = 2
        knobNode.glowWidth = 3
        addChild(knobNode)

        // Direction indicators on base
        addDirectionIndicators()

        // Initial state - semi-transparent
        alpha = UIConfig.joystickAlpha
    }

    private func addDirectionIndicators() {
        let indicatorCount = 8
        let indicatorRadius = baseRadius * 0.85

        for i in 0..<indicatorCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(indicatorCount))
            let indicator = SKShapeNode(circleOfRadius: 4)
            indicator.fillColor = SKColor.white.withAlphaComponent(0.3)
            indicator.strokeColor = .clear
            indicator.position = CGPoint(
                x: cos(angle) * indicatorRadius,
                y: sin(angle) * indicatorRadius
            )
            baseNode.addChild(indicator)
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !isTracking else { return }

        isTracking = true
        trackingTouch = touch

        let touchLocation = touch.location(in: self.parent!)

        if isDynamic {
            // Move joystick to touch location
            position = touchLocation
            initialTouchPosition = .zero
        } else {
            initialTouchPosition = touchLocation
        }

        // Reset knob position
        knobNode.position = .zero

        // Visual feedback - increase opacity
        run(SKAction.fadeAlpha(to: 1.0, duration: 0.1))

        // Subtle scale animation
        let scaleAction = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.05)
        ])
        run(scaleAction)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking, let touch = trackingTouch, touches.contains(touch) else { return }

        let touchLocation = touch.location(in: self)
        updateKnobPosition(touchLocation)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking, let touch = trackingTouch, touches.contains(touch) else { return }
        endTracking()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking, let touch = trackingTouch, touches.contains(touch) else { return }
        endTracking()
    }

    // MARK: - Joystick Logic

    private func updateKnobPosition(_ touchLocation: CGPoint) {
        // Calculate distance from center
        let dx = touchLocation.x
        let dy = touchLocation.y
        let distance = sqrt(dx * dx + dy * dy)

        // Maximum knob travel distance
        let maxDistance = baseRadius - knobRadius / 2

        if distance <= maxDistance {
            // Within bounds - move knob directly
            knobNode.position = touchLocation
        } else {
            // Outside bounds - clamp to edge
            let angle = atan2(dy, dx)
            knobNode.position = CGPoint(
                x: cos(angle) * maxDistance,
                y: sin(angle) * maxDistance
            )
        }

        // Calculate normalized direction
        let normalizedDistance = min(distance / maxDistance, 1.0)

        if normalizedDistance > deadzone {
            let angle = atan2(dy, dx)
            let adjustedMagnitude = (normalizedDistance - deadzone) / (1.0 - deadzone)

            currentDirection = CGVector(
                dx: cos(angle) * adjustedMagnitude,
                dy: sin(angle) * adjustedMagnitude
            )
        } else {
            currentDirection = .zero
        }

        // Notify delegate
        delegate?.joystickDidMove(direction: currentDirection)
    }

    private func endTracking() {
        isTracking = false
        trackingTouch = nil
        currentDirection = .zero

        // Animate knob back to center
        let returnAction = SKAction.move(to: .zero, duration: 0.1)
        returnAction.timingMode = .easeOut
        knobNode.run(returnAction)

        // Return to default opacity
        run(SKAction.fadeAlpha(to: UIConfig.joystickAlpha, duration: 0.2))

        // Notify delegate
        delegate?.joystickDidEnd()
    }

    // MARK: - Public Methods

    func reset() {
        endTracking()
    }

    func setEnabled(_ enabled: Bool) {
        isUserInteractionEnabled = enabled
        alpha = enabled ? UIConfig.joystickAlpha : UIConfig.joystickAlpha * 0.5

        if !enabled {
            reset()
        }
    }
}

// MARK: - Fixed Position Joystick Variant

class FixedJoystick: VirtualJoystick {

    override init(baseSize: CGFloat = UIConfig.joystickBaseSize,
                  knobSize: CGFloat = UIConfig.joystickKnobSize) {
        super.init(baseSize: baseSize, knobSize: knobSize)
        isDynamic = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Touch Zone for Dynamic Joystick

class JoystickTouchZone: SKNode {

    // MARK: - Properties

    weak var joystick: VirtualJoystick?
    var touchZoneRect: CGRect = .zero

    // MARK: - Initialization

    init(rect: CGRect, joystick: VirtualJoystick) {
        super.init()

        self.touchZoneRect = rect
        self.joystick = joystick
        isUserInteractionEnabled = true

        // Visual debug zone (optional)
        #if DEBUG
        let debugZone = SKShapeNode(rect: rect)
        debugZone.fillColor = SKColor.blue.withAlphaComponent(0.1)
        debugZone.strokeColor = SKColor.blue.withAlphaComponent(0.3)
        debugZone.lineWidth = 1
        debugZone.zPosition = -1
        addChild(debugZone)
        #endif
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Touch Forwarding

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        if touchZoneRect.contains(location) {
            joystick?.touchesBegan(touches, with: event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystick?.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystick?.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystick?.touchesCancelled(touches, with: event)
    }
}
