# Moneko iOS Widget Setup

To enable the iOS widget, you need to add a Widget Extension target in Xcode.

1.  Open `ios/Runner.xcworkspace` in Xcode.
2.  Go to **File > New > Target...**
3.  Select **Widget Extension** and click **Next**.
4.  Name the product **MonekoWidget**.
5.  Uncheck "Include Configuration Intent" (we are using a StaticConfiguration).
6.  Click **Finish**.
7.  If asked to activate the scheme, click **Activate**.
8.  In the Project Navigator, find the newly created `MonekoWidget` folder.
9.  Delete the default `MonekoWidget.swift` (or `MonekoWidgetBundle.swift` if present).
10. Drag and drop the `MonekoWidget.swift` file from this directory (`ios/MonekoWidget/MonekoWidget.swift`) into the `MonekoWidget` group in Xcode. Ensure "Copy items if needed" is unchecked (to link to this file) or checked (to copy it).
    *   *Alternative:* Just copy the content of `ios/MonekoWidget/MonekoWidget.swift` and paste it into the `MonekoWidget.swift` created by Xcode.
11. Ensure the `MonekoWidget` target has the correct Deployment Target (e.g., iOS 17.0 or matching your app).

## App Groups (Optional but Recommended)
If you plan to share data between the app and the widget in the future:
1.  Select the **Runner** target -> **Signing & Capabilities**.
2.  Click **+ Capability** and add **App Groups**.
3.  Add a new group `group.moneko.mobile`.
4.  Select the **MonekoWidget** target -> **Signing & Capabilities**.
5.  Add **App Groups** capability.
6.  Select the same group `group.moneko.mobile`.
