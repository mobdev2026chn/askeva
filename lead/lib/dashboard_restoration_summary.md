# Dashboard & Navigation Restoration

## Overview
Restored the "Bottom Navigation Bar + Dashboard + AppBar" structure while keeping the new Leads functionality.

## Changes

1.  **DashboardPage (`lead/lib/modules/dashboard/dashboard_page.dart`)**:
    *   **Structure**: `Scaffold` > `PageView` + `BottomNavigationBar`.
    *   **Tab 1 (Dashboard)**: Contains `DashboardOverview` wrapped in `Scaffold` with `AppBar` & Logout button.
    *   **Tab 2 (Leads)**: Embeds `MainTabScreen` (the Leads/Companies top-tab view). Logic consolidated.
    *   **Tab 3 (Settings)**: Contains `LeadSettingsPage` wrapped in `Scaffold` with `AppBar`.
    *   **Bottom Navigation**: Switch between Dashboard, Leads, and Settings.

2.  **Navigation Flow**:
    *   **SplashScreen**: Redirects to `DashboardPage` on auto-login.
    *   **LoginPage**: Redirects to `DashboardPage` on success.

## User Experience
- App launch -> Splash -> Auto-login or Login Screen.
- **Home Screen (Dashboard)**:
    - **Bottom Nav**: Always visible.
    - **Dashboard Tab**: Stats, charts, reports. Logout available here.
    - **Leads Tab**: The CRM view with "New Lead", Filters, and Top Tabs for Leads/Companies.
    - **Settings Tab**: App settings.

## Note
- The `MainTabScreen` (Leads view) still has a Logout button in its AppBar. I left it there as requested "appbar... all this" implies keeping features. It might be redundant but safe.
