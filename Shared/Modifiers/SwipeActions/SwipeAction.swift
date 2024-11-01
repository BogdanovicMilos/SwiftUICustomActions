//
//  SwipeAction.swift
//  SwiftUICustomActions
//
//  Created by Milos Bogdanovic on 10/31/24.
//

import SwiftUI


struct SwipeAction<Label: View, Background: View>: View {
    
    // MARK: - Properties
    
    /// Read the `swipeContext` from the parent `SwipeView`.
    @Environment(\.swipeContext) var swipeContext

    /// Keeps track of whether the action is pressed/triggered or not.
    @State var highlighted = false

    /// Set to true to enable drag-to-trigger on the edge action. If `nil`, this is not the edge action.
    public var allowSwipeToTrigger: Bool?

    /// Constrain the action's content size (helpful for text).
    public var labelFixedSize = true

    /// Additional horizontal padding.
    public var labelHorizontalPadding = Double(16)

    /// Whether to ramp the opacity of the entire view or just the label.
    public var changeLabelVisibilityOnly = false

    /// Code to run when the action triggers.
    public var action: () -> Void

    /// The parameter indicates if it's highlighted or not.
    public var label: (Bool) -> Label

    /// The background of the swipe action.
    public var background: (Bool) -> Background

    // MARK: - Initialization
    
    public init(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (Bool) -> Label,
        @ViewBuilder background: @escaping (Bool) -> Background
    ) {
        self.action = action
        self.label = label
        self.background = background
    }
    
    // MARK: - View
    
    public var body: some View {
        let labelAlignment: Alignment = {
            guard let allowSwipeToTrigger, allowSwipeToTrigger else { return .center }
            if swipeContext.numberOfActions == 1 {
                if swipeContext.state.wrappedValue == .triggering || swipeContext.state.wrappedValue == .triggered {
                    return swipeContext.side.edgeTriggerAlignment
                }
            }
            return .center
        }()

        let (totalOpacity, labelOpacity): (Double, Double) = {
            if changeLabelVisibilityOnly {
                return (1, swipeContext.opacity)
            } else {
                return (swipeContext.opacity, 1)
            }
        }()

        Button(action: action) {
            background(highlighted)
                .overlay(
                    label(highlighted)
                        .opacity(labelOpacity)
                        .fixedSize(horizontal: labelFixedSize, vertical: labelFixedSize)
                        .padding(.horizontal, labelHorizontalPadding),
                    alignment: labelAlignment
                )
        }
        .opacity(totalOpacity)
        ._onButtonGesture { pressing in
            self.highlighted = pressing
        } perform: {}
        .buttonStyle(SwipeActionButtonStyle())
        .onChange(of: swipeContext.state.wrappedValue) { state in
            guard let allowSwipeToTrigger, allowSwipeToTrigger else { return }

            if let state {
                if state == .triggering || state == .triggered {
                    highlighted = true
                } else {
                    highlighted = false
                }

                if state == .triggered {
                    action()
                }
            } else {
                highlighted = false
            }
        }
        .preference(key: AllowSwipeToTriggerKey.self, value: allowSwipeToTrigger)
    }
}

// MARK: - Extensions

extension SwipeAction where Label == Text, Background == Color {
    init(
        _ title: LocalizedStringKey,
        backgroundColor: Color = Color.primary.opacity(0.1),
        highlightOpacity: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.init(action: action) { highlight in
            Text(title)
        } background: { highlight in
            backgroundColor
                .opacity(highlight ? highlightOpacity : 1)
        }
    }
}

extension SwipeAction where Label == Image, Background == Color {
    init(
        systemImage: String,
        backgroundColor: Color = Color.primary.opacity(0.1),
        highlightOpacity: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.init(action: action) { highlight in
            Image(systemName: systemImage)
        } background: { highlight in
            backgroundColor
                .opacity(highlight ? highlightOpacity : 1)
        }
    }
}

extension SwipeAction where Label == VStack<TupleView<(ModifiedContent<Image, _EnvironmentKeyWritingModifier<Font?>>, Text)>>, Background == Color {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        imageFont: Font? = .title2,
        backgroundColor: Color = Color.primary.opacity(0.1),
        highlightOpacity: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.init(action: action) { highlight in
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(imageFont) as! ModifiedContent<Image, _EnvironmentKeyWritingModifier<Font?>>

                Text(title)
            }
        } background: { highlight in
            backgroundColor
                .opacity(highlight ? highlightOpacity : 1)
        }
    }
}

extension SwipeAction {
    /**
     Apply this to the edge action to enable drag-to-trigger.

         SwipeView {
             Text("Swipe")
         } leadingActions: { _ in
             SwipeAction("1") {}
                 .allowSwipeToTrigger()

             SwipeAction("2") {}
         } trailingActions: { _ in
             SwipeAction("3") {}

             SwipeAction("4") {}
                 .allowSwipeToTrigger()
         }
     */
    func allowSwipeToTrigger(_ value: Bool = true) -> some View {
        var view = self
        view.allowSwipeToTrigger = value
        return view
    }

    /// Constrain the action's content size (helpful for text).
    func swipeActionLabelFixedSize(_ value: Bool = true) -> SwipeAction {
        var view = self
        view.labelFixedSize = value
        return view
    }

    /// Additional horizontal padding.
    func swipeActionLabelHorizontalPadding(_ value: Double = 16) -> SwipeAction {
        var view = self
        view.labelHorizontalPadding = value
        return view
    }

    /// The opacity of the swipe actions, determined by `actionsVisibleStartPoint` and `actionsVisibleEndPoint`.
    func swipeActionChangeLabelVisibilityOnly(_ value: Bool) -> SwipeAction {
        var view = self
        view.changeLabelVisibilityOnly = value
        return view
    }
}
