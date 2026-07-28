# Workflow: Update Persistent Login

## Overview
Implemented persistent login by saving tokens and checking login state on app startup.

## Changes
1.  **Backend**: No changes.
2.  **AuthService**: Already supported `saveToken`, `getToken`, `clearToken`.
3.  **LoginPage**: Already saved token on success.
4.  **MainTabScreen**: Added **Logout** button to `AppBar`.
    - Confirms logout.
    - Clears token.
    - Redirects to `LoginPage`.
5.  **SplashScreen**: Created new `SplashScreen` widget.
    - Checks for token on init.
    - Redirects to `MainTabScreen` if logged in.
    - Redirects to `LoginPage` if not.
6.  **Main**: Updated `main.dart` to use `SplashScreen` as the `home` widget.

## Status
- [x] Login persistence
- [x] Auto-login on restart
- [x] Logout functionality
