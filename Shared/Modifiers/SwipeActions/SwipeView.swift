//
//  SwipeView.swift
//  SwiftUICustomActions
//
//  Created by Milos Bogdanovic on 11/01/24.
//

import SwiftUI


enum SwipeState {
    case closed
    case expanded
    case triggering
    case triggered
}

enum SwipeSide {
    case leading
    case trailing

    /// When leading actions are shown, the offset is positive. It's the opposite for trailing actions.
    var signWhenDragged: Int {
        switch self {
        case .leading:
            return 1
        case .trailing:
            return -1
        }
    }

    var alignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }

    /// Used when there's only one action.
    var edgeTriggerAlignment: Alignment {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        }
    }
}

/// Context for the swipe action.
public struct SwipeContext {
    var state: Binding<SwipeState?>
    var numberOfActions = 0
    var side: SwipeSide
    var opacity = Double(0)
    var currentlyDragging = false
}

/// The style to reveal actions.
public enum SwipeActionStyle {
    case mask
    case equalWidths
    case cascade
}

/// Options for configuring the swipe view.
public struct SwipeOptions {
    /// If swiping is currently enabled.
    var swipeEnabled = true

    /// The minimum distance needed to drag to start the gesture. Should be more than 0 for best compatibility with other gestures/buttons.
    var swipeMinimumDistance = Double(2)

    /// The style to use (`mask`, `equalWidths`, or `cascade`).
    var actionsStyle = SwipeActionStyle.mask

    /// The corner radius that encompasses all actions.
    var actionsMaskCornerRadius = Double(20)

    /// At what point the actions start becoming visible.
    var actionsVisibleStartPoint = Double(50)

    /// At what point the actions become fully visible.
    var actionsVisibleEndPoint = Double(100)

    /// The corner radius for each action.
    var actionCornerRadius = Double(32)

    /// The width for each action.
    var actionWidth = Double(100)

    /// Spacing between actions and the label view.
    var spacing = Double(8)

    /// The point where the user must drag to expand actions.
    var readyToExpandPadding = Double(50)

    /// The point where the user must drag to enter the `triggering` state.
    var readyToTriggerPadding = Double(20)

    /// Ensure that the user must drag a significant amount to trigger the edge action, even if the actions' total width is small.
    var minimumPointToTrigger = Double(200)

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is true.
    var enableTriggerHaptics = true

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is false, or when there's no actions on one side.
    var stretchRubberBandingPower = Double(0.7)

    /// If true, you can change from the leading to the trailing actions in one single swipe.
    var allowSingleSwipeAcross = false

    /// The animation used for adjusting the content's view when it's triggered.
    var actionContentTriggerAnimation = Animation.spring(response: 0.2, dampingFraction: 1, blendDuration: 1)

    /// Values for controlling the close animation.
    var offsetCloseAnimationStiffness = Double(160), offsetCloseAnimationDamping = Double(70)

    /// Values for controlling the expand animation.
    var offsetExpandAnimationStiffness = Double(160), offsetExpandAnimationDamping = Double(70)

    /// Values for controlling the trigger animation.
    var offsetTriggerAnimationStiffness = Double(160), offsetTriggerAnimationDamping = Double(70)
}

// MARK: - Environment

public struct SwipeContextKey: EnvironmentKey {
    public static let defaultValue = SwipeContext(state: .constant(nil), side: .leading)
}

public struct SwipeViewGroupSelectionKey: EnvironmentKey {
    public static let defaultValue: Binding<UUID?> = .constant(nil)
}

public extension EnvironmentValues {
    var swipeContext: SwipeContext {
        get { self[SwipeContextKey.self] }
        set { self[SwipeContextKey.self] = newValue }
    }

    var swipeViewGroupSelection: Binding<UUID?> {
        get { self[SwipeViewGroupSelectionKey.self] }
        set { self[SwipeViewGroupSelectionKey.self] = newValue }
    }
}

// MARK: - Group view

/**
 To only allow one swipe view open at a time, use this view.

     SwipeViewGroup {
         SwipeView {} /// Only one will be shown.
         SwipeView {}
         SwipeView {}
     }

 */
struct SwipeViewGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State var selection: UUID?

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .environment(\.swipeViewGroupSelection, $selection)
    }
}

// MARK: - Swipe View

struct SwipeView<Label, LeadingActions, TrailingActions>: View where Label: View, LeadingActions: View, TrailingActions: View {
    
    // MARK: - Properties

    /// Options for configuring the swipe view.
    public var options = SwipeOptions()

    @ViewBuilder public var label: () -> Label
    @ViewBuilder public var leadingActions: (SwipeContext) -> LeadingActions
    @ViewBuilder public var trailingActions: (SwipeContext) -> TrailingActions

    // MARK: - Environment

    /// Read the `swipeViewGroupSelection` from the parent `SwipeViewGroup` (if it exists).
    @Environment(\.swipeViewGroupSelection) var swipeViewGroupSelection

    /// The ID of the view. Set `options.id` to override this.
    @State var id = UUID()

    /// The size of the parent view.
    @State var size = CGSize.zero

    /// The current side that's showing the actions.
    @State var currentSide: SwipeSide?

    /// The `closed/expanded/triggering/triggered/none` state for the leading side.
    @State var leadingState: SwipeState?

    /// The `closed/expanded/triggering/triggered/none` state for the trailing side.
    @State var trailingState: SwipeState?

    /// These properties are set automatically via `SwipeActionsLayout`.
    @State var numberOfLeadingActions = 0
    @State var numberOfTrailingActions = 0

    /// Enable triggering the leading edge via a drag.
    @State var swipeToTriggerLeadingEdge = false

    /// Enable triggering the trailing edge via a drag.
    @State var swipeToTriggerTrailingEdge = false

    /// When you touch down with a second finger, the drag gesture freezes, but `currentlyDragging` will be accurate.
    @GestureState var currentlyDragging = false

    /// Upon a gesture freeze / cancellation, use this to end the gesture.
    @State var latestDragGestureValueBackup: DragGesture.Value?

    /// The gesture's current velocity.
    @GestureVelocity var velocity: CGVector

    /// The offset dragged in the current drag session.
    @State var currentOffset = Double(0)

    /// The offset dragged in previous drag sessions.
    @State var savedOffset = Double(0)

    /// A view for adding swipe actions.
    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder leadingActions: @escaping (SwipeContext) -> LeadingActions,
        @ViewBuilder trailingActions: @escaping (SwipeContext) -> TrailingActions
    ) {
        self.label = label
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
    }
    
    // MARK: - View

    public var body: some View {
        HStack {
            label()
                .offset(x: offset) /// Apply the offset here.
        }
        .readSize { size = $0 }
        .background( /// Leading swipe actions.
            actionsView(side: .leading, state: $leadingState, numberOfActions: $numberOfLeadingActions) { context in
                leadingActions(context)
                    .environment(\.swipeContext, context)
                    .onPreferenceChange(AllowSwipeToTriggerKey.self) { allow in

                        /// Unwrap the value first (if it's not the edge action, `allow` is `nil`).
                        if let allow {
                            swipeToTriggerLeadingEdge = allow
                        }
                    }
            },
            alignment: .leading
        )
        .background( /// Trailing swipe actions.
            actionsView(side: .trailing, state: $trailingState, numberOfActions: $numberOfTrailingActions) { context in
                trailingActions(context)
                    .environment(\.swipeContext, context)
                    .onPreferenceChange(AllowSwipeToTriggerKey.self) { allow in
                        if let allow {
                            swipeToTriggerTrailingEdge = allow
                        }
                    }
            },
            alignment: .trailing
        )

        // MARK: - Add gestures

        .highPriorityGesture( /// Add the drag gesture.
            DragGesture(minimumDistance: options.swipeMinimumDistance)
                .updating($currentlyDragging) { value, state, transaction in
                    state = true
                }
                .onChanged(onChanged)
                .onEnded(onEnded)
                .updatingVelocity($velocity),
            including: options.swipeEnabled ? .all : .subviews
        )
        .onChange(of: currentlyDragging) { currentlyDragging in
            if !currentlyDragging, let latestDragGestureValueBackup {
                /// Gesture cancelled.
                let velocity = velocity.dx / currentOffset
                end(value: latestDragGestureValueBackup, velocity: velocity)
            }
        }

        // MARK: - Receive `SwipeViewGroup` events

        .onChange(of: currentlyDragging) { newValue in
            if newValue {
                swipeViewGroupSelection.wrappedValue = id
            }
        }
        .onChange(of: leadingState) { newValue in
            if newValue == .closed, swipeViewGroupSelection.wrappedValue == id {
                swipeViewGroupSelection.wrappedValue = nil
            }
        }
        .onChange(of: trailingState) { newValue in
            if newValue == .closed, swipeViewGroupSelection.wrappedValue == id {
                swipeViewGroupSelection.wrappedValue = nil
            }
        }
        .onChange(of: swipeViewGroupSelection.wrappedValue) { newValue in
            if swipeViewGroupSelection.wrappedValue != id {
                currentSide = nil

                if leadingState != .closed {
                    leadingState = .closed
                    close(velocity: 0)
                }

                if trailingState != .closed {
                    trailingState = .closed
                    close(velocity: 0)
                }
            }
        }
    }
}

// MARK: - Actions view

extension SwipeView {
    /// The swipe actions.
    @ViewBuilder func actionsView<Actions: View>(
        side: SwipeSide,
        state: Binding<SwipeState?>,
        numberOfActions: Binding<Int>,
        @ViewBuilder actions: (SwipeContext) -> Actions
    ) -> some View {
        let draggedLength = offset * Double(side.signWhenDragged) /// Flip the offset if necessary.
        let visibleWidth: Double = {
            var width = draggedLength
            width -= options.spacing /// Minus the side spacing.
            width = max(0, width) /// Prevent from becoming negative.
            return width
        }()

        let opacity: Double = {
            /// Subtract the start point from the dragged length, which cancels it out initially.
            let offset = max(0, draggedLength - options.actionsVisibleStartPoint)

            /// Calculate the opacity percent.
            let percent = offset / (options.actionsVisibleEndPoint - options.actionsVisibleStartPoint)

            /// Make sure the opacity doesn't exceed 1.
            let opacity = min(1, percent)

            return opacity
        }()

        _VariadicView.Tree(
            SwipeActionLayout(
                numberOfActions: numberOfActions,
                side: side,
                options: options,
                state: state.wrappedValue,
                visibleWidth: visibleWidth
            )
        ) {
            let stateBinding = Binding {
                state.wrappedValue
            } set: { newValue in
                state.wrappedValue = newValue

                if newValue == .closed {
                    currentSide = nil /// If closed, set `currentSide` to nil.
                } else {
                    currentSide = side /// Set the current side to the action's side.
                }

                /// Update the visual state to the client's new selection.
                updateOffset(side: side, to: newValue)
            }

            let context = SwipeContext(
                state: stateBinding,
                numberOfActions: numberOfActions.wrappedValue,
                side: side,
                opacity: opacity,
                currentlyDragging: currentlyDragging
            )

            actions(context) /// Call the `actions` view and pass in context.
        }
        .mask(
            Color.clear.overlay(
                /// Clip the swipe actions as they're being revealed.
                RoundedRectangle(cornerRadius: options.actionsMaskCornerRadius, style: .continuous)
                    .frame(width: visibleWidth),
                alignment: side.alignment
            )
        )
    }
}

// MARK: - Calculated values

extension SwipeView {
    /// The total offset of the content.
    var offset: Double {
        currentOffset + savedOffset
    }

    /// Calculate the total width for actions.
    func actionsWidth(numberOfActions: Int) -> Double {
        let count = Double(numberOfActions)
        let totalWidth = count * options.actionWidth
        let totalSpacing = (count - 1) * options.spacing
        let actionsWidth = totalWidth + totalSpacing

        return actionsWidth
    }

    /// If `allowSwipeAcross` is disabled, make sure the user can't swipe from one side to the other in a single swipe.
    func getDisallowedSide(totalOffset: Double) -> SwipeSide? {
        guard !options.allowSingleSwipeAcross else { return nil }
        if let currentSide {
            switch currentSide {
            case .leading:
                if totalOffset < 0 {
                    /// Disallow showing trailing actions.
                    return .trailing
                }
            case .trailing:
                if totalOffset > 0 {
                    /// Disallow showing leading actions.
                    return .leading
                }
            }
        }
        return nil
    }

    // MARK: - Trailing

    var trailingReadyToExpandOffset: Double {
        -options.readyToExpandPadding
    }

    var trailingExpandedOffset: Double {
        let expandedOffset = -(actionsWidth(numberOfActions: numberOfTrailingActions) + options.spacing)
        return expandedOffset
    }

    var trailingReadyToTriggerOffset: Double {
        var readyToTriggerOffset = trailingExpandedOffset - options.readyToTriggerPadding
        let minimumOffsetToTrigger = -options.minimumPointToTrigger
        if readyToTriggerOffset > minimumOffsetToTrigger {
            readyToTriggerOffset = minimumOffsetToTrigger
        }
        return readyToTriggerOffset
    }

    var trailingTriggeredOffset: Double {
        let triggeredOffset = -(size.width + options.spacing)
        return triggeredOffset
    }

    // MARK: - Leading

    var leadingReadyToExpandOffset: Double {
        options.readyToExpandPadding
    }

    var leadingExpandedOffset: Double {
        let expandedOffset = actionsWidth(numberOfActions: numberOfLeadingActions) + options.spacing
        return expandedOffset
    }

    var leadingReadyToTriggerOffset: Double {
        var readyToTriggerOffset = leadingExpandedOffset + options.readyToTriggerPadding
        let minimumOffsetToTrigger = options.minimumPointToTrigger

        if readyToTriggerOffset < minimumOffsetToTrigger {
            readyToTriggerOffset = minimumOffsetToTrigger
        }
        return readyToTriggerOffset
    }

    var leadingTriggeredOffset: Double {
        let triggeredOffset = size.width + options.spacing
        return triggeredOffset
    }
}

// MARK: - State

extension SwipeView {
    func updateOffset(side: SwipeSide, to state: SwipeState?) {
        guard let state else { return }
        switch state {
        case .closed:
            close(velocity: 0)
        case .expanded:
            expand(side: side, velocity: 0)
        case .triggering:
            break
        case .triggered:
            trigger(side: side, velocity: 0)
        }
    }

    func close(velocity: Double) {
        withAnimation(.interpolatingSpring(stiffness: options.offsetTriggerAnimationStiffness, damping: options.offsetTriggerAnimationDamping, initialVelocity: velocity)) {
            savedOffset = 0
            currentOffset = 0
        }
    }

    func trigger(side: SwipeSide, velocity: Double) {
        withAnimation(.interpolatingSpring(stiffness: options.offsetTriggerAnimationStiffness, damping: options.offsetTriggerAnimationDamping, initialVelocity: velocity)) {
            switch side {
            case .leading:
                savedOffset = leadingTriggeredOffset
            case .trailing:
                savedOffset = trailingTriggeredOffset
            }
            currentOffset = 0
        }
    }

    func expand(side: SwipeSide, velocity: Double) {
        withAnimation(.interpolatingSpring(stiffness: options.offsetExpandAnimationStiffness, damping: options.offsetExpandAnimationDamping, initialVelocity: velocity)) {
            switch side {
            case .leading:
                savedOffset = leadingExpandedOffset
            case .trailing:
                savedOffset = trailingExpandedOffset
            }
            currentOffset = 0
        }
    }
}

// MARK: - Gestures

extension SwipeView {
    func onChanged(value: DragGesture.Value) {
        latestDragGestureValueBackup = value

        /// Set the current side.
        if currentSide == nil {
            let dx = value.location.x - value.startLocation.x
            if dx > 0 {
                currentSide = .leading
            } else {
                currentSide = .trailing
            }
        } else {
            change(value: value)
        }
    }

    func change(value: DragGesture.Value) {
        /// The total offset of the swipe view.
        let totalOffset = savedOffset + value.translation.width

        /// Get the disallowed side if it exists.
        let disallowedSide = getDisallowedSide(totalOffset: totalOffset)

        /// Apply rubber banding if an empty side is reached, or if a side is disallowed.
        if numberOfLeadingActions == 0 || disallowedSide == .leading, totalOffset > 0 {
            let constrainedExceededOffset = pow(totalOffset, options.stretchRubberBandingPower)
            currentOffset = constrainedExceededOffset - savedOffset
            leadingState = nil
            trailingState = nil
        } else if numberOfTrailingActions == 0 || disallowedSide == .trailing, totalOffset < 0 {
            let constrainedExceededOffset = -pow(-totalOffset, options.stretchRubberBandingPower)
            currentOffset = constrainedExceededOffset - savedOffset
            leadingState = nil
            trailingState = nil
        } else {
            var setCurrentOffset = false

            if totalOffset > leadingReadyToTriggerOffset {
                setCurrentOffset = true
                if swipeToTriggerLeadingEdge {
                    currentOffset = value.translation.width
                    leadingState = .triggering
                    trailingState = nil
                } else {
                    let exceededOffset = totalOffset - leadingReadyToTriggerOffset
                    let constrainedExceededOffset = pow(exceededOffset, options.stretchRubberBandingPower)
                    let constrainedTotalOffset = leadingReadyToTriggerOffset + constrainedExceededOffset
                    currentOffset = constrainedTotalOffset - savedOffset
                    leadingState = nil
                    trailingState = nil
                }
            }

            if totalOffset < trailingReadyToTriggerOffset {
                setCurrentOffset = true
                if swipeToTriggerTrailingEdge {
                    currentOffset = value.translation.width
                    trailingState = .triggering
                    leadingState = nil
                } else {
                    let exceededOffset = totalOffset - trailingReadyToTriggerOffset
                    let constrainedExceededOffset = -pow(-exceededOffset, options.stretchRubberBandingPower)
                    let constrainedTotalOffset = trailingReadyToTriggerOffset + constrainedExceededOffset
                    currentOffset = constrainedTotalOffset - savedOffset
                    leadingState = nil
                    trailingState = nil
                }
            }

            /// If the offset wasn't modified already (due to rubber banding), use `value.translation.width` as the default.
            if !setCurrentOffset {
                currentOffset = value.translation.width
                leadingState = nil
                trailingState = nil
            }
        }
    }

    func onEnded(value: DragGesture.Value) {
        latestDragGestureValueBackup = nil
        let velocity = velocity.dx / currentOffset
        end(value: value, velocity: velocity)
    }

    /// Represents the end of a gesture.
    func end(value: DragGesture.Value, velocity: CGFloat) {
        let totalOffset = savedOffset + value.translation.width
        let totalPredictedOffset = (savedOffset + value.predictedEndTranslation.width) * 0.5

        if getDisallowedSide(totalOffset: totalPredictedOffset) != nil {
            currentSide = nil
            leadingState = .closed
            trailingState = .closed
            close(velocity: velocity)
            return
        }

        if trailingState == .triggering {
            trailingState = .triggered
            trigger(side: .trailing, velocity: velocity)
        } else if leadingState == .triggering {
            leadingState = .triggered
            trigger(side: .leading, velocity: velocity)
        } else {
            if totalPredictedOffset > leadingReadyToExpandOffset, numberOfLeadingActions > 0 {
                leadingState = .expanded
                expand(side: .leading, velocity: velocity)
            } else if totalPredictedOffset < trailingReadyToExpandOffset, numberOfTrailingActions > 0 {
                trailingState = .expanded
                expand(side: .trailing, velocity: velocity)
            } else {
                currentSide = nil
                leadingState = .closed
                trailingState = .closed
                let draggedPastTrailingSide = totalOffset > 0
                if draggedPastTrailingSide {
                    close(velocity: velocity * -0.1)
                } else {
                    close(velocity: velocity)
                }
            }
        }
    }
}

// MARK: - Convenience views

/// A `SwipeView` with leading actions only.
extension SwipeView where TrailingActions == EmptyView {
    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder leadingActions: @escaping (SwipeContext) -> LeadingActions
    ) {
        self.init(label: label, leadingActions: leadingActions) { _ in }
    }
}

/// A `SwipeView` with trailing actions only.
extension SwipeView where LeadingActions == EmptyView {
    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder trailingActions: @escaping (SwipeContext) -> TrailingActions
    ) {
        self.init(label: label, leadingActions: { _ in }, trailingActions: trailingActions)
    }
}

/// A `SwipeView` with no actions.
extension SwipeView where LeadingActions == EmptyView, TrailingActions == EmptyView {
    init(@ViewBuilder label: @escaping () -> Label) {
        self.init(label: label) { _ in } trailingActions: { _ in }
    }
}

// MARK: - Convenience modifiers

extension SwipeView {
    /// If swiping is currently enabled.
    func swipeEnabled(_ value: Bool) -> SwipeView {
        var view = self
        view.options.swipeEnabled = value
        return view
    }

    /// The minimum distance needed to drag to start the gesture. Should be more than 0 for best compatibility with other gestures/buttons.
    func swipeMinimumDistance(_ value: Double) -> SwipeView {
        var view = self
        view.options.swipeMinimumDistance = value
        return view
    }

    /// The style to use (`mask`, `equalWidths`, or `cascade`).
    func swipeActionsStyle(_ value: SwipeActionStyle) -> SwipeView {
        var view = self
        view.options.actionsStyle = value
        return view
    }

    /// The corner radius that encompasses all actions.
    func swipeActionsMaskCornerRadius(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionsMaskCornerRadius = value
        return view
    }

    /// At what point the actions start becoming visible.
    func swipeActionsVisibleStartPoint(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionsVisibleStartPoint = value
        return view
    }

    /// At what point the actions become fully visible.
    func swipeActionsVisibleEndPoint(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionsVisibleEndPoint = value
        return view
    }

    /// The corner radius for each action.
    func swipeActionCornerRadius(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionCornerRadius = value
        return view
    }

    /// The width for each action.
    func swipeActionWidth(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionWidth = value
        return view
    }

    /// Spacing between actions and the label view.
    func swipeSpacing(_ value: Double) -> SwipeView {
        var view = self
        view.options.spacing = value
        return view
    }

    /// The point where the user must drag to expand actions.
    func swipeReadyToExpandPadding(_ value: Double) -> SwipeView {
        var view = self
        view.options.readyToExpandPadding = value
        return view
    }

    /// The point where the user must drag to enter the `triggering` state.
    func swipeReadyToTriggerPadding(_ value: Double) -> SwipeView {
        var view = self
        view.options.readyToTriggerPadding = value
        return view
    }

    /// Ensure that the user must drag a significant amount to trigger the edge action, even if the actions' total width is small.
    func swipeMinimumPointToTrigger(_ value: Double) -> SwipeView {
        var view = self
        view.options.minimumPointToTrigger = value
        return view
    }

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is true.
    func swipeEnableTriggerHaptics(_ value: Bool) -> SwipeView {
        var view = self
        view.options.enableTriggerHaptics = value
        return view
    }

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is false, or when there's no actions on one side.
    func swipeStretchRubberBandingPower(_ value: Double) -> SwipeView {
        var view = self
        view.options.stretchRubberBandingPower = value
        return view
    }

    /// If true, you can change from the leading to the trailing actions in one single swipe.
    func swipeAllowSingleSwipeAcross(_ value: Bool) -> SwipeView {
        var view = self
        view.options.allowSingleSwipeAcross = value
        return view
    }

    /// The animation used for adjusting the content's view when it's triggered.
    func swipeActionContentTriggerAnimation(_ value: Animation) -> SwipeView {
        var view = self
        view.options.actionContentTriggerAnimation = value
        return view
    }

    /// Values for controlling the close animation.
    func swipeOffsetCloseAnimation(stiffness: Double, damping: Double) -> SwipeView {
        var view = self
        view.options.offsetCloseAnimationStiffness = stiffness
        view.options.offsetCloseAnimationDamping = damping
        return view
    }

    /// Values for controlling the expand animation.
    func swipeOffsetExpandAnimation(stiffness: Double, damping: Double) -> SwipeView {
        var view = self
        view.options.offsetExpandAnimationStiffness = stiffness
        view.options.offsetExpandAnimationDamping = damping
        return view
    }

    /// Values for controlling the trigger animation.
    func swipeOffsetTriggerAnimation(stiffness: Double, damping: Double) -> SwipeView {
        var view = self
        view.options.offsetTriggerAnimationStiffness = stiffness
        view.options.offsetTriggerAnimationDamping = damping
        return view
    }
}

/// Modifier for a clipped delete transition effect.
public struct SwipeDeleteModifier: ViewModifier {
    var visibility: Double

    public func body(content: Content) -> some View {
        content
            .mask(
                Color.clear.overlay(
                    SwipeDeleteMaskShape(animatableData: visibility)
                        .padding(.horizontal, -100) /// Prevent horizontal clipping
                        .padding(.vertical, -10), /// Prevent vertical clipping
                    alignment: .top
                )
            )
    }
}

public extension AnyTransition {
    static var swipeDelete: AnyTransition {
        .modifier(
            active: SwipeDeleteModifier(visibility: 0),
            identity: SwipeDeleteModifier(visibility: 1)
        )
    }
}

public struct SwipeDeleteMaskShape: Shape {
    public var animatableData: Double

    public func path(in rect: CGRect) -> Path {
        var maskRect = rect
        maskRect.size.height = rect.size.height * animatableData
        return Path(maskRect)
    }
}

// MARK: - Utilities

/// A style to remove the "press" effect on buttons.
public struct SwipeActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        return configuration.label
    }
}

@propertyWrapper
struct GestureVelocity: DynamicProperty {
    @State var previous: DragGesture.Value?
    @State var current: DragGesture.Value?

    func update(_ value: DragGesture.Value) {
        if current != nil {
            previous = current
        }

        current = value
    }

    func reset() {
        previous = nil
        current = nil
    }

    var projectedValue: GestureVelocity {
        return self
    }

    var wrappedValue: CGVector {
        value
    }

    private var value: CGVector {
        guard
            let previous,
            let current
        else {
            return .zero
        }

        let timeDelta = current.time.timeIntervalSince(previous.time)

        let speedY = Double(
            current.translation.height - previous.translation.height
        ) / timeDelta

        let speedX = Double(
            current.translation.width - previous.translation.width
        ) / timeDelta

        return .init(dx: speedX, dy: speedY)
    }
}

extension Gesture where Value == DragGesture.Value {
    func updatingVelocity(_ velocity: GestureVelocity) -> _EndedGesture<_ChangedGesture<Self>> {
        onChanged { value in
            velocity.update(value)
        }
        .onEnded { _ in
            velocity.reset()
        }
    }
}

extension View {
    func readSize(size: @escaping (CGSize) -> Void) -> some View {
        return background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ContentSizeReaderPreferenceKey.self, value: geometry.size)
                    .onPreferenceChange(ContentSizeReaderPreferenceKey.self) { newValue in
                        DispatchQueue.main.async {
                            size(newValue)
                        }
                    }
            }
            .hidden()
        )
    }
}

struct ContentSizeReaderPreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { return CGSize() }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct AllowSwipeToTriggerKey: PreferenceKey {
    static var defaultValue: Bool? = nil
    static func reduce(value: inout Bool?, nextValue: () -> Bool?) { value = nextValue() }
}

