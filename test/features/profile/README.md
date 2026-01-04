# Profile Feature Tests

This directory contains comprehensive widget tests for profile-related features in the Moneko mobile app.

## Test Coverage

### WhatsApp Binding Card (`whatsapp_binding_card_test.dart`)
Tests the WhatsApp integration feature card displayed in settings:

**Loading State**
- Loading indicator display
- Correct container styling and dimensions
- Loading state persistence

**Error State**
- Card hiding on error
- Graceful error handling
- No visual artifacts

**Not Bound State (CTA)**
- CTA card rendering with all elements
- "Connect WhatsApp" title and description
- "NEW" badge display
- Benefit icons (Fast, Photo, Auto-sync)
- Arrow forward icon
- Tutorial modal trigger on tap
- Gradient background styling
- WhatsApp green border

**Bound State (Connected)**
- Connected card rendering
- "WhatsApp connected" title
- Description text
- Chat bubble icon (WhatsApp green)
- Chevron right icon
- Tappable card functionality
- Correct styling and padding

**State Transitions**
- Loading → Not Bound
- Not Bound → Bound
- Bound → Not Bound
- Data → Error
- Rapid state changes

**Accessibility**
- Semantic labels for CTA card
- Semantic labels for connected card
- Icon semantic meaning
- Screen reader compatibility

**Visual Consistency**
- Consistent padding across states
- Consistent border radius (16px)
- Consistent color scheme
- WhatsApp brand colors

**Layout**
- CTA card structure (Column, Rows)
- Connected card structure (Row with icon, text, chevron)
- Benefit icons even spacing
- Proper widget hierarchy

**Edge Cases**
- Rapid state changes handling
- Widget disposal during state change
- State change race conditions

## Test Architecture

### Mocking Strategy
- **WhatsApp Binding Provider**: Overridden with test AsyncValue states
- **No External Dependencies**: Card is purely presentational
- **State-Driven Testing**: Tests cover all AsyncValue states (loading, data, error)

### Test Structure
Each test follows this pattern:
1. **Setup**: Create test widget with specific provider state
2. **Pump Widget**: Render and settle animations
3. **Assertions**: Verify UI elements and behavior
4. **State Changes**: Test transitions between states

### Key Testing Principles
- **State Coverage**: All AsyncValue states tested
- **Visual Verification**: Layout and styling assertions
- **Interaction Testing**: Tap handlers and navigation
- **Transition Testing**: State change behavior
- **Accessibility**: Semantic labels and screen reader support

## Running Tests

### Run all profile tests
```bash
cd moneko-mobile
flutter test test/features/profile/
```

### Run WhatsApp binding tests
```bash
flutter test test/features/profile/presentation/widgets/whatsapp_binding_card_test.dart
```

### Run with coverage
```bash
flutter test --coverage test/features/profile/
```

## Test Data

### Provider States
- **Loading**: `AsyncValue.loading()`
- **Not Bound**: `AsyncValue.data(false)`
- **Bound**: `AsyncValue.data(true)`
- **Error**: `AsyncValue.error(Exception('message'), stackTrace)`

### Expected UI Elements

#### CTA State (Not Bound)
- Title: "Connect WhatsApp"
- Description: "Log expenses instantly"
- Badge: "NEW"
- Benefits: "Fast", "Photo", "Auto-sync"
- Icons: `flash_on`, `receipt`, `sync`, `arrow_forward`

#### Connected State (Bound)
- Title: "WhatsApp connected"
- Description: "Log expenses via WhatsApp"
- Icons: `chat_bubble_rounded`, `chevron_right`

## Dependencies

### Test Dependencies
- `flutter_test`: Flutter testing framework
- `hooks_riverpod`: State management testing
- `mockito`: Mocking library (annotations only)

### Widget Dependencies
- `whatsapp_binding_card.dart`: Widget under test
- `whatsapp_binding_provider.dart`: State provider
- `app_localizations.dart`: Localization support

## Design Specifications

### Colors
- **WhatsApp Green**: Used for icons, borders, and accents
- **Gradient**: Green gradient for CTA background
- **Card Background**: Theme-based card color
- **Border**: WhatsApp green with alpha transparency

### Dimensions
- **Border Radius**: 16px
- **Loading Height**: 120px
- **Icon Sizes**: 22px (connected), 20px (benefits)
- **Padding**: 20px (CTA), 20/14px (connected)

### Typography
- **Title**: 18px bold (CTA), 16px semibold (connected)
- **Description**: 14px regular
- **Badge**: 10px bold
- **Benefits**: 12px regular

## Future Enhancements

### Potential Test Additions
1. **Integration Tests**: Full WhatsApp binding flow
2. **Golden Tests**: Visual regression testing
3. **Animation Tests**: Transition animations
4. **Accessibility Tests**: Screen reader navigation
5. **Localization Tests**: Multi-language support

### Areas for Expansion
- WhatsApp tutorial modal testing
- URL launching verification
- Provider refresh logic testing
- Error recovery flow testing
- Analytics event tracking
