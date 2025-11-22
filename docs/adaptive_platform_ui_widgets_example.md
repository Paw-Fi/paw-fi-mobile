### AdaptiveScaffold with AdaptiveAppBar

**Basic Usage:**
```dart
AdaptiveScaffold(
  appBar: AdaptiveAppBar(
    title: 'My App',
    actions: [
      AdaptiveAppBarAction(
        onPressed: () {},
        iosSymbol: 'gear',
        icon: Icons.settings,
      ),
    ],
  ),
  bottomNavigationBar: AdaptiveBottomNavigationBar(
    items: [
      AdaptiveNavigationDestination(
        icon: 'house.fill',
        label: 'Home',
      ),
      AdaptiveNavigationDestination(
        icon: 'person.fill',
        label: 'Profile',
      ),
    ],
    selectedIndex: 0,
    onTap: (index) {},
  ),
  body: YourContent(),
)
```

**iOS 26 Native Toolbar:**
```dart
AdaptiveScaffold(
  appBar: AdaptiveAppBar(
    title: 'My App',
    useNativeToolbar: true, // Enable native iOS 26 UIToolbar with Liquid Glass effects
    actions: [...],
  ),
  body: YourContent(),
)
```

**iOS 26 Native Bottom Bar:**
```dart
AdaptiveScaffold(
  bottomNavigationBar: AdaptiveBottomNavigationBar(
    useNativeBottomBar: true, // Enable native iOS 26 UITabBar with Liquid Glass effects (default)
    items: [...],
    selectedIndex: 0,
    onTap: (index) {},
  ),
  body: YourContent(),
)
```
**No AppBar or Bottom Navigation:**
```dart
// If appBar and bottomNavigationBar are null, neither will be shown
AdaptiveScaffold(
  body: YourContent(),
)
```

**Key Features:**
- 🎨 **AdaptiveAppBar**: Centralized app bar configuration
- 📱 **AdaptiveBottomNavigationBar**: Centralized bottom navigation configuration
- 🔧 **Custom Navigation Bars**: Provide your own navigation components
- 🌟 **Native iOS 26 Components**: Optional Liquid Glass effects with native UIKit
- 🎯 **Priority System**: Custom bars take priority over auto-generated ones
- 🔄 **Flexible**: Null parameters hide components

Adaptive Bottom Navigation Bar (Destinations):
<p align="center">
  <img src="https://raw.githubusercontent.com/berkaycatak/adaptive_platform_ui/refs/heads/main/img/bottom_nav_p.png" alt="Native Toolbar"/>
</p>


### AdaptiveButton

<img src="https://raw.githubusercontent.com/berkaycatak/adaptive_platform_ui/refs/heads/main/img/buttons_p.png" alt="iOS 26 Native Toolbar">


```dart
// Basic button with label
AdaptiveButton(
  onPressed: () {},
  label: 'Click Me',
)

// Button with custom child
AdaptiveButton.child(
  onPressed: () {},
  child: Row(
    children: [
      Icon(Icons.add),
      Text('Add Item'),
    ],
  ),
)

// Icon button
AdaptiveButton.icon(
  onPressed: () {},
  icon: Icons.favorite,
)
```

### AdaptiveAlertDialog
<img src="https://raw.githubusercontent.com/berkaycatak/adaptive_platform_ui/refs/heads/main/img/alert_p.png" alt="iOS 26 Native Toolbar">


```dart
// Basic alert dialog
AdaptiveAlertDialog.show(
  context: context,
  title: 'Confirm',
  message: 'Are you sure?',
  icon: 'checkmark.circle.fill',
  actions: [
    AlertAction(
      title: 'Cancel',
      style: AlertActionStyle.cancel,
      onPressed: () {},
    ),
    AlertAction(
      title: 'Confirm',
      style: AlertActionStyle.primary,
      onPressed: () {
        // Do something
      },
    ),
  ],
);

// Alert dialog with text input
final result = await AdaptiveAlertDialog.show(
  context: context,
  title: 'Enter Your Name',
  message: 'Please provide your name',
  icon: 'person.fill',
  input: AdaptiveAlertDialogInput(
    placeholder: 'Your name',
    initialValue: '',
    keyboardType: TextInputType.text,
  ),
  actions: [
    AlertAction(
      title: 'Cancel',
      style: AlertActionStyle.cancel,
      onPressed: () {},
    ),
    AlertAction(
      title: 'Submit',
      style: AlertActionStyle.primary,
      onPressed: () {},
    ),
  ],
);

// result contains the text entered by the user
if (result != null) {
  print('User entered: $result');
}
```

### AdaptiveContextMenu

```dart
AdaptiveContextMenu(
  actions: [
    AdaptiveContextMenuAction(
      title: 'Edit',
      icon: PlatformInfo.isIOS ? CupertinoIcons.pencil : Icons.edit,
      onPressed: () {
        print('Edit pressed');
      },
    ),
    AdaptiveContextMenuAction(
      title: 'Share',
      icon: PlatformInfo.isIOS ? CupertinoIcons.share : Icons.share,
      onPressed: () {
        print('Share pressed');
      },
    ),
    AdaptiveContextMenuAction(
      title: 'Delete',
      icon: PlatformInfo.isIOS ? CupertinoIcons.trash : Icons.delete,
      isDestructive: true,
      onPressed: () {
        print('Delete pressed');
      },
    ),
  ],
  child: Container(
    padding: EdgeInsets.all(16),
    child: Text('Long press me'),
  ),
)
```

**iOS**: Uses `CupertinoContextMenu` with preview and native animations.
**Android**: Uses `PopupMenuButton` with Material Design styling.

### AdaptivePopupMenuButton

<p align="center">
<img src="https://raw.githubusercontent.com/berkaycatak/adaptive_platform_ui/refs/heads/main/img/popup_p.png" alt="iOS 26 Native Popup">
</p>

```dart
// Text button with popup menu
AdaptivePopupMenuButton.text<String>(
  label: 'Options',
  items: [
    AdaptivePopupMenuItem(
        label: 'Edit',
        icon:  PlatformInfo.isIOS26OrHigher() ?  'pencil' : Icons.edit,
        value: 'edit',
      ),
      AdaptivePopupMenuItem(
        label: 'Delete',
        icon: PlatformInfo.isIOS26OrHigher() ?  'trash' : Icons.delete,
        value: 'delete',
      ),
      AdaptivePopupMenuDivider(),
      AdaptivePopupMenuItem(
        label: 'Share',
        icon: PlatformInfo.isIOS26OrHigher() ? 'square.and.arrow.up' : Icons.share,
        value: 'share',
      ),
  ],
  onSelected: (index, item) {
    print('Selected: ${item.value}');
  },
)

// Icon button with popup menu
AdaptivePopupMenuButton.icon<String>(
  icon: 'ellipsis.circle',
  items: [...],
  onSelected: (index, item) { },
  buttonStyle: PopupButtonStyle.glass,
)

// Custom widget with popup menu
AdaptivePopupMenuButton.widget<String>(
  items: [
    AdaptivePopupMenuItem(label: 'Option 1', value: 'opt1'),
    AdaptivePopupMenuItem(label: 'Option 2', value: 'opt2'),
  ],
  onSelected: (index, item) {
    print('Selected: ${item.value}');
  },
  child: Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.menu),
        SizedBox(width: 8),
        Text('Custom Button'),
      ],
    ),
  ),
)
```

### AdaptiveSegmentedControl

<p align="center">
  <img src="https://github.com/berkaycatak/adaptive_platform_ui/raw/main/img/segmented_control.gif" alt="Segmented Control" width="300"/>
</p>

```dart
AdaptiveSegmentedControl(
  labels: ['One', 'Two', 'Three'],
  selectedIndex: 0,
  onValueChanged: (index) {
    print('Selected: $index');
  },
)

// With icons (SF Symbols on iOS)
AdaptiveSegmentedControl(
  labels: [],
  sfSymbols: [
    'house.fill',
    'person.fill',
    'gear',
  ],
  selectedIndex: 0,
  onValueChanged: (index) {},
  iconColor: CupertinoColors.systemBlue,
)
```

### AdaptiveSwitch

<p align="center">
  <img src="https://github.com/berkaycatak/adaptive_platform_ui/raw/main/img/switch.gif" alt="Adaptive Switch" width="300"/>
</p>

```dart
AdaptiveSwitch(
  value: true,
  onChanged: (value) {
    print('Switch: $value');
  },
)
```

### AdaptiveSlider

<p align="center">
  <img src="https://github.com/berkaycatak/adaptive_platform_ui/raw/main/img/slider.gif" alt="Adaptive Slider" width="300"/>
</p>

```dart
AdaptiveSlider(
  value: 0.5,
  onChanged: (value) {
    print('Slider: $value');
  },
  min: 0.0,
  max: 1.0,
)
```

### AdaptiveCheckbox

```dart
AdaptiveCheckbox(
  value: true,
  onChanged: (value) {
    print('Checkbox: $value');
  },
)

// Tristate checkbox
AdaptiveCheckbox(
  value: null, // Can be true, false, or null
  tristate: true,
  onChanged: (value) {
    print('Checkbox: $value');
  },
)
```

### AdaptiveRadio

```dart
enum Options { option1, option2, option3 }
Options? _selectedOption = Options.option1;

AdaptiveRadio<Options>(
  value: Options.option1,
  groupValue: _selectedOption,
  onChanged: (Options? value) {
    setState(() {
      _selectedOption = value;
    });
  },
)
```

### AdaptiveCard

```dart
AdaptiveCard(
  padding: EdgeInsets.all(16),
  child: Text('Card Content'),
)

// Card with custom styling
AdaptiveCard(
  padding: EdgeInsets.all(16),
  color: Colors.blue.withValues(alpha: 0.1),
  borderRadius: BorderRadius.circular(20),
  elevation: 8, // Android only
  child: Column(
    children: [
      Text('Custom Card'),
      Text('With multiple elements'),
    ],
  ),
)
```

### AdaptiveBadge

```dart
AdaptiveBadge(
  count: 5,
  child: Icon(Icons.notifications),
)

// Badge with text label
AdaptiveBadge(
  label: 'NEW',
  backgroundColor: Colors.red,
  child: Icon(Icons.mail),
)

// Large badge
AdaptiveBadge(
  count: 99,
  isLarge: true,
  child: Icon(Icons.message),
)
```

### AdaptiveTooltip

```dart
AdaptiveTooltip(
  message: 'This is a tooltip',
  child: Icon(Icons.info),
)

// Tooltip positioned above
AdaptiveTooltip(
  message: 'Tooltip appears above',
  preferBelow: false,
  child: Icon(Icons.help),
)
```

### AdaptiveSnackBar

```dart
// Basic snackbar
AdaptiveSnackBar.show(
  context,
  message: 'Operation completed successfully!',
  type: AdaptiveSnackBarType.success,
)

// Snackbar with action button
AdaptiveSnackBar.show(
  context,
  message: 'File deleted',
  type: AdaptiveSnackBarType.info,
  action: 'Undo',
  onActionPressed: () {
    // Undo action
  },
)

// Custom duration
AdaptiveSnackBar.show(
  context,
  message: 'This will stay longer',
  duration: Duration(seconds: 8),
)

// Different types
AdaptiveSnackBar.show(context, message: 'Info', type: AdaptiveSnackBarType.info);
AdaptiveSnackBar.show(context, message: 'Success', type: AdaptiveSnackBarType.success);
AdaptiveSnackBar.show(context, message: 'Warning', type: AdaptiveSnackBarType.warning);
AdaptiveSnackBar.show(context, message: 'Error', type: AdaptiveSnackBarType.error);
```

**iOS**: Banner-style notification at the top with slide/fade animations, tap to dismiss, and icon indicators.
**Android**: Material SnackBar at the bottom with standard Material Design appearance.

### AdaptiveDatePicker

```dart
// Basic date picker
final selectedDate = await AdaptiveDatePicker.show(
  context: context,
  initialDate: DateTime.now(),
);

// Date picker with range
final selectedDate = await AdaptiveDatePicker.show(
  context: context,
  initialDate: DateTime.now(),
  firstDate: DateTime(2020),
  lastDate: DateTime(2025),
);

// Date and time picker (iOS)
final selectedDateTime = await AdaptiveDatePicker.show(
  context: context,
  initialDate: DateTime.now(),
  mode: CupertinoDatePickerMode.dateAndTime,
);

if (selectedDate != null) {
  print('Selected: ${selectedDate.toString()}');
}
```

**iOS**: Uses `CupertinoDatePicker` in a modal bottom sheet with Cancel/Done buttons.
**Android**: Uses Material `DatePickerDialog`.

### AdaptiveTimePicker

```dart
// 12-hour format
final selectedTime = await AdaptiveTimePicker.show(
  context: context,
  initialTime: TimeOfDay.now(),
  use24HourFormat: false,
);

// 24-hour format
final selectedTime = await AdaptiveTimePicker.show(
  context: context,
  initialTime: TimeOfDay.now(),
  use24HourFormat: true,
);

if (selectedTime != null) {
  print('Selected: ${selectedTime.format(context)}');
}
```

**iOS**: Uses `CupertinoDatePicker` in time mode in a modal bottom sheet.
**Android**: Uses Material `TimePickerDialog`.

### AdaptiveListTile

```dart
// Basic list tile
AdaptiveListTile(
  title: Text('Profile'),
  subtitle: Text('View your profile'),
  onTap: () {
    // Handle tap
  },
)

// List tile with leading and trailing
AdaptiveListTile(
  leading: Icon(Icons.person),
  title: Text('Profile'),
  subtitle: Text('View your profile'),
  trailing: Icon(Icons.chevron_right),
  onTap: () {
    // Handle tap
  },
)

// Selectable list tile
AdaptiveListTile(
  leading: Icon(Icons.star),
  title: Text('Favorite'),
  selected: true,
  trailing: Icon(Icons.check_circle),
  onTap: () {
    // Handle tap
  },
)

// List tile with custom trailing widget
AdaptiveListTile(
  title: Text('Enable Feature'),
  subtitle: Text('Toggle to enable'),
  trailing: AdaptiveSwitch(
    value: switchValue,
    onChanged: (value) {
      // Handle change
    },
  ),
)
```

**iOS**: Uses CupertinoListTile-like styling with bottom border separator.
**Android**: Uses Material `ListTile`.

### AdaptiveTextField

```dart
// Basic text field
AdaptiveTextField(
  placeholder: 'Enter your name',
  onChanged: (value) {
    print('Text: $value');
  },
)

// Text field with icons
AdaptiveTextField(
  placeholder: 'Search',
  prefixIcon: Icon(
    PlatformInfo.isIOS ? CupertinoIcons.search : Icons.search,
  ),
  suffixIcon: IconButton(
    icon: Icon(
      PlatformInfo.isIOS ? CupertinoIcons.clear : Icons.clear,
    ),
    onPressed: () {
      // Clear text
    },
  ),
)

// Password field
AdaptiveTextField(
  placeholder: 'Enter password',
  obscureText: true,
  prefixIcon: Icon(
    PlatformInfo.isIOS ? CupertinoIcons.lock : Icons.lock,
  ),
)

// Multiline text field
AdaptiveTextField(
  placeholder: 'Enter description',
  maxLines: 5,
  minLines: 3,
  keyboardType: TextInputType.multiline,
)
```

**iOS**: Uses `CupertinoTextField` with tertiarySystemBackground color and rounded corners.
**Android**: Uses Material `TextField` with outlined border.

### AdaptiveTextFormField

```dart
// Form with validation
Form(
  key: _formKey,
  child: Column(
    children: [
      AdaptiveTextFormField(
        placeholder: 'Email',
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your email';
          }
          if (!value.contains('@')) {
            return 'Please enter a valid email';
          }
          return null;
        },
        onSaved: (value) => _email = value,
      ),
      AdaptiveButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();
            // Process form
          }
        },
        label: 'Submit',
      ),
    ],
  ),
)
```

**iOS**: Uses custom `FormField` wrapper with `CupertinoTextField` for proper validation with error display.
**Android**: Uses Material `TextFormField`.

### AdaptiveFloatingActionButton

```dart
// Basic floating action button
AdaptiveFloatingActionButton(
  onPressed: () {},
  child: Icon(Icons.add),
)

// Mini FAB
AdaptiveFloatingActionButton(
  onPressed: () {},
  mini: true,
  child: Icon(Icons.edit),
)

// Custom colors
AdaptiveFloatingActionButton(
  onPressed: () {},
  backgroundColor: Colors.red,
  foregroundColor: Colors.white,
  child: Icon(Icons.favorite),
)
```

**iOS**: Circular button with custom shadow effects.
**Android**: Material `FloatingActionButton` with elevation.

### AdaptiveFormSection

```dart
// Basic form section
AdaptiveFormSection(
  header: Text('Personal Information'),
  footer: Text('Please provide accurate information'),
  children: [
    CupertinoFormRow(
      prefix: Text('Name'),
      child: AdaptiveTextField(placeholder: 'Enter name'),
    ),
    CupertinoFormRow(
      prefix: Text('Email'),
      child: AdaptiveTextField(placeholder: 'Enter email'),
    ),
  ],
)

// Inset grouped style
AdaptiveFormSection.insetGrouped(
  header: Text('Settings'),
  children: [
    CupertinoFormRow(
      prefix: Text('Notifications'),
      child: AdaptiveSwitch(value: true, onChanged: (v) {}),
    ),
  ],
)
```

**iOS**: Uses `CupertinoFormSection` with native iOS styling.
**Android**: Uses Material `Card` with similar grouped layout.

### AdaptiveExpansionTile

```dart
// Basic expansion tile
AdaptiveExpansionTile(
  title: Text('Settings'),
  children: [
    ListTile(title: Text('Option 1')),
    ListTile(title: Text('Option 2')),
  ],
)

// With leading and subtitle
AdaptiveExpansionTile(
  leading: Icon(Icons.settings),
  title: Text('Advanced Settings'),
  subtitle: Text('Configure advanced options'),
  initiallyExpanded: true,
  children: [
    ListTile(title: Text('Option 1')),
    ListTile(title: Text('Option 2')),
  ],
)

// With custom colors
AdaptiveExpansionTile(
  title: Text('Premium Features'),
  backgroundColor: Colors.amber.withValues(alpha: 0.1),
  iconColor: Colors.amber,
  onExpansionChanged: (expanded) {
    print('Expanded: $expanded');
  },
  children: [
    ListTile(title: Text('Feature 1')),
    ListTile(title: Text('Feature 2')),
  ],
)
```

**iOS**: Modern custom design with rounded corners, smooth shadows, animated chevron, and gradient separator.
**Android**: Material `ExpansionTile` with InkWell effects.

### AdaptiveTabBarView

Horizontal swipeable tab view with tabs at the top.

```dart
// Tab bar view at the top
AdaptiveTabBarView(
  tabs: ['Latest', 'Popular', 'Trending'],
  children: [
    LatestPage(),
    PopularPage(),
    TrendingPage(),
  ],
  onTabChanged: (index) {
    print('Tab changed to: $index');
  },
)
```

**iOS**: Uses `CupertinoSlidingSegmentedControl` for tab selection.
**Android**: Uses Material `TabBar` + `TabBarView`.

## Usage

### Button Styles

```dart
// Filled button (primary action)
AdaptiveButton(
  onPressed: () {},
  style: AdaptiveButtonStyle.filled,
  label: 'Filled',
)

// Tinted button (secondary action)
AdaptiveButton(
  onPressed: () {},
  style: AdaptiveButtonStyle.tinted,
  label: 'Tinted',
)

// Gray button (neutral action)
AdaptiveButton(
  onPressed: () {},
  style: AdaptiveButtonStyle.gray,
  label: 'Gray',
)

// Bordered button
AdaptiveButton(
  onPressed: () {},
  style: AdaptiveButtonStyle.bordered,
  label: 'Bordered',
)

// Plain text button
AdaptiveButton(
  onPressed: () {},
  style: AdaptiveButtonStyle.plain,
  label: 'Plain',
)
```

### Button Sizes

```dart
// Small button (28pt height on iOS)
AdaptiveButton(
  onPressed: () {},
  size: AdaptiveButtonSize.small,
  label: 'Small',
)

// Medium button (36pt height on iOS) - default
AdaptiveButton(
  onPressed: () {},
  size: AdaptiveButtonSize.medium,
  label: 'Medium',
)

// Large button (44pt height on iOS)
AdaptiveButton(
  onPressed: () {},
  size: AdaptiveButtonSize.large,
  label: 'Large',
)
```

### Custom Styling

```dart
AdaptiveButton(
  onPressed: () {},
  label: 'Custom Button',
  color: Colors.red,
  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  borderRadius: BorderRadius.circular(16),
  minSize: Size(200, 50),
)
```

### Disabled State

```dart
AdaptiveButton(
  onPressed: () {},
  label: 'Disabled',
  enabled: false,
)
```

## Platform Detection

Use the `PlatformInfo` utility class to check platform and iOS version:

```dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

// Check platform
if (PlatformInfo.isIOS) {
  print('Running on iOS');
}

if (PlatformInfo.isAndroid) {
  print('Running on Android');
}

// Check iOS version
if (PlatformInfo.isIOS26OrHigher()) {
  print('Using iOS 26+ features');
}

if (PlatformInfo.isIOS18OrLower()) {
  print('Using legacy iOS widgets');
}

// Get iOS version number
int version = PlatformInfo.iOSVersion; // e.g., 26

// Check version range
if (PlatformInfo.isIOSVersionInRange(24, 26)) {
  print('iOS version is between 24 and 26');
}

// Get platform description
String description = PlatformInfo.platformDescription; // e.g., "iOS 26"
```