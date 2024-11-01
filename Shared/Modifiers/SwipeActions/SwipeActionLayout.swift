//
//  SwipeActionLayout.swift
//  SwiftUICustomActions
//
//  Created by Milos Bogdanovic on 10/31/24.
//

import SwiftUI


struct SwipeActionLayout: _VariadicView_UnaryViewRoot {
    
    // MARK: - Properties
    
    @Binding var numberOfActions: Int
    var side: SwipeSide
    var options: SwipeOptions
    var state: SwipeState?
    var visibleWidth: Double
    
    // MARK: - View
    
    @ViewBuilder
    public func body(children: _VariadicView.Children) -> some View {
        let edgeID: AnyHashable? = {
            switch side {
            case .leading:
                return children.first?.id
            case .trailing:
                return children.last?.id
            }
        }()
        
        HStack(spacing: options.spacing) {
            ForEach(Array(zip(children.indices, children)), id: \.1.id) { index, child in
                let isEdge = child.id == edgeID
                
                let shown: Bool = {
                    if state == .triggering || state == .triggered {
                        if !isEdge {
                            return false
                        }
                    }
                    
                    return true
                }()
                
                let width: CGFloat? = {
                    if state == .triggering || state == .triggered {
                        if isEdge {
                            return visibleWidth
                        } else {
                            return 0
                        }
                    }
                    
                    let evenlyDistributedActionWidth: Double = {
                        if numberOfActions > 0 {
                            let visibleWidthWithoutSpacing = visibleWidth - options.spacing * Double(numberOfActions - 1)
                            let evenlyDistributedActionWidth = visibleWidthWithoutSpacing / Double(numberOfActions)
                            return evenlyDistributedActionWidth
                        } else {
                            return options.actionWidth
                        }
                    }()
                    
                    switch options.actionsStyle {
                    case .mask:
                        return max(evenlyDistributedActionWidth, options.actionWidth)
                    case .equalWidths:
                        return evenlyDistributedActionWidth
                    case .cascade:
                        return max(evenlyDistributedActionWidth, options.actionWidth)
                    }
                }()
                
                if options.actionsStyle == .cascade {
                    let zIndex: Int = {
                        switch side {
                        case .leading:
                            return children.count - index - 1
                        case .trailing:
                            return index
                        }
                    }()
                    
                    Color.clear.overlay(
                        child
                            .frame(maxHeight: .infinity)
                            .frame(width: width)
                            .opacity(shown ? 1 : 0)
                            .mask(
                                RoundedRectangle(cornerRadius: options.actionCornerRadius, style: .continuous)
                            ),
                        alignment: side.edgeTriggerAlignment
                    )
                    .zIndex(Double(zIndex))
                } else {
                    child
                        .frame(maxHeight: .infinity)
                        .frame(width: width)
                        .opacity(shown ? 1 : 0)
                        .mask(
                            RoundedRectangle(cornerRadius: options.actionCornerRadius, style: .continuous)
                        )
                }
            }
        }
        .frame(width: options.actionsStyle == .cascade ? visibleWidth : nil)
        .animation(options.actionContentTriggerAnimation, value: state)
        .onAppear {
            numberOfActions = children.count
        }
        .onChange(of: children.count) { count in
            numberOfActions = count
        }
    }
}
