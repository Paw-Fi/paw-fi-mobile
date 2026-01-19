# Plan Selection Page Walkthrough

## Overview
A fully native in-app **Plan Selection Page** has been implemented to allow users to manage their Moneko subscription directly from the mobile app, without redirecting to a web browser.

## Features
1.  **View Plans**: Displays 'Starter' (Free), 'Plus', and 'Lifetime' plans.
2.  **Billing Interval**: Toggle between **Monthly** and **Yearly** billing with dynamic pricing.
3.  **Native Upgrade**:
    *   Uses the Moneko backend API (`update-subscription`) to process upgrades immediately.
    *   **Note**: This relies on the user having a valid payment method on file (or usage of platform-specific billing if integrated later).
    *   Displays a native **Confirmation Dialog** with exact pricing details before processing.
4.  **Downgrade/Cancel**: Instantly cancels subscription via API with confirmation.
5.  **Switch Interval**: Seamlessly switches billing cycles for existing subscriptions.

## Technical Implementation

### 1. PlanSelectionPage (`plan_selection_page.dart`)
-   **State Management**: `hooks_riverpod` watching `subscriptionManagementProvider`.
-   **No Browser**: `url_launcher` usage has been removed. All actions are handled via API calls.
-   **API Integration**:
    -   Calls `changePlan(plan: ..., billingInterval: ...)` on `SubscriptionManagementNotifier`.
    -   Handles errors gracefully (e.g., prompting user if payment fails).
-   **UI**:
    -   `AdaptiveScaffold` / `AdaptiveAppBar`.
    -   `MonekoAlertDialog` for all confirmations.
    -   Type-safe navigation from Settings.

### 2. Provider (`subscription_management_provider.dart`)
-   Updated `changePlan` and `previewSubscriptionChange` to accept nullable `billingInterval` (e.g., for Lifetime plans).
-   Wraps Supabase Edge Functions: `update-subscription`, `preview-subscription-change`.

## Usage
1.  Go to **Settings** -> **Membership**.
2.  Select a plan (e.g., Plus Yearly).
3.  Tap **Upgrade**.
4.  Confirm the native dialog (e.g., "Upgrade to Plus for $49.00/year?").
5.  Success toast appears upon completion.
