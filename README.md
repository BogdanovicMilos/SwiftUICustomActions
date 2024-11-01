# SwiftUI custom actions

The SwiftUICustomActions example demonstrates how to set up custom swipe actions for a List in SwiftUI. This CustomSwipeAction component lets you add dynamic actions, such as delete or edit, directly to each list cell, with customizable icons, colors, and labels.

https://github.com/user-attachments/assets/6f2c3a74-fb09-4535-8d6a-d8ecdc32bf91

### Features

- Custom Swipe Actions: Add actions with customizable buttons, colors, and icons.
- Flexible Layouts: Configure single or multiple actions per cell with easy customization.
- Adaptive Design: Supports light and dark mode and adapts based on system accessibility settings.
- Animation Support: Smooth animations for swiping and interacting with list items.

### Example Implementation

Below is a basic implementation to get you started:

```swift
SwipeView {
    ZStack(alignment: .leading) {
        itemRow(item)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 6)
    .padding(EdgeInsets(top: -1, leading: 0, bottom: -1, trailing: 0))
    .listRowInsets(EdgeInsets())
    .background(Color(uiColor: Color.accountBackgroundPrimary))
    .cornerRadius(20)
} trailingActions: { _ in
    SwipeAction(systemImage: "trash", backgroundColor: Color.red.opacity(0.7)) {
        showingOptions = true
    }
}
.swipeActionsStyle(.cascade)
.swipeActionCornerRadius(20)
.swipeSpacing(2)
```
