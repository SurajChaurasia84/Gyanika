# Gyanika (Learner App)

Motto: Learning made simple.

Gyanika is a Flutter + Firebase learning community app where users can:
- discover subjects and practice sets,
- attempt quizzes and polls,
- create and interact with posts (questions/polls/quizzes),
- follow other users,
- receive activity/notification updates,
- personalize their home feed using categories and preferences.

This repository folder (`gyanika/`) contains the learner-facing mobile app.

## Tech Stack

- Flutter (Dart, Material 3)
- Firebase
  - Authentication
  - Cloud Firestore
- Local storage: Hive
- UI helpers: Shimmer, Iconsax, Flutter SVG

## App Flow (High Level)

1. App starts from `lib/main.dart`.
2. `AuthGate` decides screen based on auth state:
   - Not logged in -> Login
   - Logged in but email not verified -> Email verification
   - Logged in + verified -> Main app
3. Main app (`MainScreen`) has 4 bottom tabs:
   - `HomeSection`
   - `LibrarySection`
   - `ExploreSection`
   - `ProfileScreen`

## Major Modules

## Authentication
- `lib/screens/auth/login_screen.dart`
  - Email/password login
  - Forgot password flow with confirmation + cooldown
- `lib/screens/auth/signup_screen.dart`
  - Account creation + Firestore user document bootstrap
  - Email verification trigger
- `lib/screens/auth/email_verification_screen.dart`
  - Verification status checks
- `lib/screens/auth/username_setup.dart`
  - Username onboarding
- `lib/screens/auth/select_category_screen.dart`
  - Category selection (onboarding + settings update mode)
  - Also caches selected categories locally in Hive to reduce reads

## Home
- `lib/screens/home_section.dart`
  - Hero cards (Daily Practice, Mock Tests, Recommended)
  - Personalized “For You” feed
    - Category-based + following-based aggregation
  - Pull-to-refresh manual reload
  - Daily practice / mock test rendering and answer handling

## Library & Explore
- `lib/screens/library_section.dart`
  - Post feed by tab/type with interaction actions
- `lib/screens/explore_section.dart`
  - Stream/subject browsing grid
  - `wl.png` banner opens `AbcdScreen` directly

## Subject & Practice
- `lib/screens/subject_screen.dart`
  - Subject chapter/set listing for normal subjects
  - ABCD subject directly routes to `AbcdScreen`
- `lib/screens/abcd.dart`
  - Direct ABCD style screen
- `lib/screens/chapter_sets_screen.dart`
  - Set test and analytics

## Profile, Activity, Settings
- `lib/screens/profile_screen.dart`
  - Profile + posts + follow/unfollow + report flow
- `lib/screens/my_profile_screen.dart`
  - Logged-in profile dashboard
- `lib/screens/activity_screen.dart`
  - Activity feed view
- `lib/screens/notification_screen.dart`
  - Notification list and settings
- `lib/screens/settings_screen.dart`
  - Name edit, category update, password reset trigger, logout

## Local Storage (Hive)

Boxes used in app:

- `settings`
  - theme preferences
  - cached preference stream
  - cached profile letter
  - cached user categories (`user_categories_<uid>`)
  - in-app notification toggles
- `messages`
  - search history and local cached pieces
- `progress`
  - set attempt/progress related local state

## Setup

## 1) Prerequisites
- Flutter SDK (matching your project constraints)
- Dart SDK
- Android Studio / VS Code
- Firebase project configured

## 2) Install dependencies

```bash
flutter pub get
```

## 3) Firebase config

Ensure these are present and valid:
- `firebase_options.dart`
- platform Firebase files (Android/iOS as required)

## 4) Run app

```bash
flutter run
```

## Useful Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Important Query/Index Notes

Some Firestore queries need composite indexes (for example `where` + `orderBy` combinations such as category/following feed queries).  
If runtime gives an index error, open the generated Firebase Console link and create the suggested index.

## Troubleshooting

- Login works but cannot enter app:
  - Check email verification status and auth rules.
- Feed empty unexpectedly:
  - Verify post fields and user selected categories alignment.
  - Confirm Firestore indexes for feed queries.
- Duplicate key / navigation odd behavior:
  - Avoid nesting another `MaterialApp` in push flows.
- Too many Firestore reads:
  - Use pull-to-refresh/manual fetch patterns and local caching where available.

## Related Project

The workspace also includes `gyanika_admin` for admin workflows (content management side).

---
