# Expenty — Current Scope & Handoff

> Snapshot: 17 Nov 2026. Read this first to onboard; then run `flutter analyze` and `flutter test` to confirm green.

## 1. What it is
**Expenty** — personal finance tracker **+ Splitwise-style group expense splitter**, Flutter app at `D:\Flutter Project\expenty`.
Currency is **₹ (en_IN)** everywhere — hard-coded in `lib/core/utils/currency_formatter.dart`. **Do not change it.**

## 2. Stack & architecture
- Flutter **3.35.6** stable, Android-first (user tests on device).
- **Clean Architecture**, per feature: `lib/features/<feature>/{domain,data,presentation}` (entities → repositories iface → datasources → repo impl → use cases → bloc → pages/widgets).
- **BLoC** (flutter_bloc 9) + **get_it** DI (`lib/app/di/service_locator.dart`), **go_router** 17 (`lib/app/app_router.dart`, `route_names.dart`).
- **Firebase**: Auth (Email/Password — enabled & verified working; **Google Sign-In wired in code**, needs the Web client ID — §6.3) + **Cloud Firestore** + **Firebase Storage** (dependency present, avatar upload parked — see §5).
- Firebase project `expenty-wise`, Android package `com.anandchowbey.expenty` (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart` all present).

## 3. Verified status
- `flutter analyze` → **No issues found**
- `flutter test` → **100 tests passing** (15 files in `test/`)
- `flutter build apk --debug` → builds (`build/app/outputs/flutter-apk/app-debug.apk`)
- `flutter build appbundle --release` → builds (`build/app/outputs/bundle/release/app-release.aab`), **but still signed with the DEBUG keystore** — see §6 before uploading.

## 4. Features DONE
- **Auth**: login (email + **Google**, see §6.3), full sign-up form, forgot password, logout (Menu tab). Routes wired; profile + directory docs written on signup (Google sign-in seeds them too, first login only).
- **Dashboard** (matches the provided mock): navy Total Balance card, Income/Expense card, Top-5 expenses (current week), 4-tab bottom nav, live Firestore data, empty/error states with Retry.
- **Wallet / Add balance**: “+ Add balance” pill on the balance card → bottom sheet (quick chips ₹500/1000/2000/5000).
  **Total Balance = wallet balance + income − expenses** (`users/{uid}.walletBalance`, atomic `FieldValue.increment`).
- **Transactions**: Add Transaction page (type/amount/title/date/category/note), edit + delete supported; drives dashboard data. Wallet top-ups are locked (delete only).
- **Groups (Splitwise-style)** — replaced the old “Merchants” tab:
  - Groups tab (list + your net per group), New group page (**invite by email → must be a registered Expenty user**).
  - Group detail: **Settlements only** — per-member net (“Rahul owes ₹500” / “You are owed ₹300”), no pairwise ledger; expense list with split breakdown dialog + delete (confirm) + edit (with reason/audit note).
  - Add expense with **4 split modes: Equal · Ratio · Percentage · Custom amount**, live per-member preview, totals validation.
  - `memberBalances` map on the group doc is updated inside a **Firestore transaction** on add/delete expense.
  - Dashboard card **“Across your groups → You owe / You are owed”** below Total Balance.
- **Profile** (`RouteNames.profile` → `ProfilePage`): view/edit **display name** and **@username** (atomic `usernames/{handle}` claim, reserved-handle + regex rules), read-only email. Each save button spins **on its own** (`ProfileSaveTarget` in `profile_state.dart`) — only the pressed button loads, the other is disabled for the duration.
- **Settings** (`RouteNames.settings`): dark mode, currency picker, notification toggles, change password, **Reset wallet balance** (DATA), **Delete account** (ACCOUNT), about.
- **Reset wallet balance** (17 Nov 2026): Settings → DATA → confirm dialog → writes `users/{uid}.walletBalance = 0` (`WalletModel.toResetMap()` — a literal `0`, *not* `increment(0)`, which would leave the old value in place). Income/expense/transaction history is untouched; the dashboard updates live through the existing wallet stream. Path: `ResetBalanceUseCase` → `WalletRemoteDataSource.resetBalance()`.
- **Delete account** (17 Nov 2026): Settings → ACCOUNT → red tile → confirm dialog → **re-authenticate → delete Firestore data → `user.delete()`**. That order is deliberate: Firebase refuses `user.delete()` on a stale session, and wiping the documents first would strand a half-deleted account. Password accounts must re-enter the password (`requiresPasswordConfirmation()` reads `currentUser.providerData`, so Google accounts never see the field and are re-authed through the Google picker instead). Cleanup: leave every group (sole member + creator → the group *and* its expenses are deleted, because `LeaveGroupUseCase` refuses to remove a last member) → release `usernames/{handle}` → batch-delete `users/{uid}/transactions` → `users/{uid}` → `profiles/{uid}` → the Auth record. Then the page routes to `/login`.
- **Splash & branding** (17 Nov 2026): the OS launch screen (Android `drawable*/launch_background.xml` + `values/colors.xml`, iOS `LaunchScreen.storyboard`) is navy **#0D132B** with the GIF's first frame centred at 300 dp, and `SplashPage` then plays `assets/images/splash_animation.gif` for 2 s before routing to login/dashboard. The login header and the launcher icon both come from `assets/images/logo.png`.

## 5. Halfway / parked features (audited 14 Nov 2026)

**Parked on purpose**
1. **Profile photo upload** — `ProfilePage._photoUploadEnabled = false`. Firebase Storage rejects `avatars/{uid}.jpg`, so the camera badge only toasts **“Profile photo is coming soon”**; an existing photo still renders read-only. The whole pipeline (image_picker → image_cropper → `ProfileStorageDataSource` → `UpdateProfilePhotoUseCase`) stays wired in `service_locator.dart`. Re-enable = flip that flag **after** creating the Storage bucket and running `firebase deploy --only storage`.
2. **Dashboard “My Balances” arrow** → `_comingSoon('My Balances')` snackbar (`dashboard_page.dart`). Only remaining `coming-soon` hook in the app.

**Dead on arrival (silently do nothing)**
3. ~~Login “Continue with Google” / “Continue with Apple”~~ — **fixed 14 Nov**: Apple button deleted, Google now dispatches `GoogleSignInRequested` and goes through the full datasource → Firebase credential flow. It fails with an explicit message until §6.3 (Web client ID) is done.
4. **Group settle-up action** — settlements are display-only; there is no “record settlement” button (ideas list).

**Never built (docs listed them, code does not exist)**
5. **Budget tab / spend-vs-budget grid** — `PROJECT_STATUS.md` used to claim it; there is **no** `lib/features/budgets/` and zero `budget` matches under `lib/`.
6. `architecute` (root file) outlines `category/`, `settlement/`, `analytics/`, `transaction/`, `core/enums`, `core/errors`, `core/network` — none of those exist.

**Dead files (never imported anywhere — safe to delete)**
`app/router/app_routes.dart`, `app/theme/app_radius.dart`, `app/theme/app_spacing.dart`,
`core/constants/{app_constants,asset_constants}.dart` (note: `firebase_constants.dart` is **live** — it holds the Google Web client ID, and `app_assets.dart` is **live** since 17 Nov — splash GIF + login logo. `app_constants.dart` is a byte-identical twin that declares a *second* `class AppAssets`: delete it, never import both),
`core/extensions/context_extensions.dart`, `core/failures/failure.dart`, `core/failures/firebase_failure.dart`,
`core/exceptions/app_exception.dart`, `core/firebase/*` (all 4: auth/messaging/storage/firestore services),
`core/services/connectivity_service.dart`, `core/utils/date_formatter.date.dart`,
`core/widgets/{app_card,app_logo}.dart`. Note `core/firebase/firebase_messaging_service.dart` duplicates `core/services/firebase_messaging_service.dart` (the services one is the live one).
Also stray at repo root: `A.java` (contains one line of text) and `summ.txt` (a stale byte-for-byte copy of this file).

## 6. ⚠️ Blocker — user must do in Firebase/Google console
1. **Create the Firestore database** (probe returned `404: database (default) does not exist`):
   `console.cloud.google.com/datastore/setup?project=expenty-wise` → Production mode.
2. **Publish rules** — the canonical files in the repo root are the source of truth:
   - `firebase deploy --only firestore:rules,storage` (or paste `firestore.rules` + `storage.rules` by hand).
   - ⚠️ Do **not** use the old snippet that used to live here: it had `allow update: if false;` on `groups/.../expenses` (which blocks the edit-expense flow) and it was missing `usernames/{handle}` (which the profile page's username claim needs) and the `storage.rules` avatar path.
   - Storage: the bucket must exist in the Firebase console (`expenty-wise.appspot.com` / `expenty-wise.firebasestorage.app`) before avatar uploads can work — this is why §5 parks the photo feature.
3. **Google Sign-In (code is ready, config is not)** — `google-services.json` has `"oauth_client": []`, so the button reports *"Google Sign-In is not set up yet…"* until you:
   1. Get the **release SHA-1**: `keytool -list -v -keystore <upload-keystore>.jks -alias upload` (or the debug one: `%USERPROFILE%\.android\debug.keystore`, alias `androiddebugkey`, store/key password `android`).
   2. Firebase Console → ⚙ Project settings → Your apps → **Add fingerprint** → paste the SHA-1 → Save.
   3. Google Cloud Console → APIs & Services → Credentials → **Create credentials → OAuth client ID → Web application** → authorise the package `com.anandchowbey.expenty` with that SHA-1 → copy the client ID (`….apps.googleusercontent.com`).
   4. Firebase Console → Authentication → Sign-in method → **Google** → paste it into **Web client ID** → Save.
   5. Paste the same ID into `FirebaseConstants.googleWebClientId` in `lib/core/constants/firebase_constants.dart`.
4. **Release signing** — `android/app/build.gradle.kts` still falls back to `signingConfig = signingConfigs.getByName("debug")`, which Google Play rejects. Generate an upload keystore, add `android/key.properties` + a `release` signing config, then rebuild the bundle.

## 7. Firestore schema
| Path | Contents |
|---|---|
| `users/{uid}` | `name, email, username, photoUrl, walletBalance, walletUpdatedAt`; subcollections `transactions/{id}` |
| `profiles/{uid}` | `{uid, name, email, emailLower, username, photoUrl}` — public directory for invite-by-email (written at signup, re-synced when Groups tab watches) |
| `usernames/{handle}` | `{uid, username}` — unique `@username` claim, written inside a Firestore transaction by the profile page |
| `groups/{gid}` | `name, createdBy, createdAt, memberIds[], members[{uid,name,email}], memberBalances{uid: net}` |
| `groups/{gid}/expenses/{id}` | `title, amount, paidBy, splitType, shares{uid: amount}, splitLabel, date, createdAt, createdBy` |

Balance rule: **payer credited the full amount, every member debited their share** → negative = still owes, positive = overpaid (pure math in `lib/features/groups/domain/group_balances.dart`, splits in `split_calculator.dart`).

## 8. Conventions & traps (learned the hard way)
- **₹ / en_IN** — never switch to `$`.
- **Splash colour is a four-way contract**: `AppColors.splashBackground` (#0D132B) must stay identical to the first frame of `assets/images/splash_animation.gif`, to `splash_background` in `android/…/values/colors.xml`, and to the iOS launch storyboard — otherwise the OS splash flashes white before the animation starts. Android 12+ reads `android:windowSplashScreenBackground` and **falls back to white for a drawable `windowBackground`**, hence `values-v31/styles.xml` + `values-night-v31/styles.xml`. ⚠️ Qualifier order is `night` **before** `v31`: a folder named `values-v31-night` dies with *Invalid resource directory name*. Native launch images are 300 dp wide (`drawable-xhdpi` 600 px, `drawable-xxxhdpi` 1200 px) to match `width: 300` in `SplashPage`.
- **Launcher icon**: source is `assets/images/logo.png`, config is the `flutter_launcher_icons:` block at the bottom of `pubspec.yaml`; re-run `dart run flutter_launcher_icons` after changing the art. It writes legacy `mipmap-*` PNGs only — **no `mipmap-anydpi-v26`**, on purpose: the artwork carries its own background and an adaptive mask would crop it.
- **Pink/purple buttons** (`AppColors.primary` #865A9A) take `AppColors.onPrimary` (#120216) for labels, icons and spinners — never `Colors.white`. It is deliberately a `const`, not theme-aware: the fill is identical in both themes. Applies to `ElevatedButton` theme, `PrimaryButton`, and every primary-filled chip/badge.
- BLoCs are `registerFactory` in `service_locator.dart`; tests do `await setupLocator()` → `sl.unregister<XRepository>()` → register a fake (keeps `FirebaseAuth.instance` untouched).
- Widget tests need a tall viewport: `tester.view.physicalSize = const Size(1080, 2400); devicePixelRatio = 1.0; addTearDown(tester.view.reset);` and `GoogleFonts.config.allowRuntimeFetching = false`.
- Read blocs only from a context **below** the provider (pass `blocContext` into handlers) or you get `ProviderNotFoundException`.
- `copyWith` must **preserve fields not passed** (wiping `group` broke the group page once).
- Never dispose a `TextEditingController` right after `await showModalBottomSheet` — own it in a `StatefulWidget` (it killed the app with `_dependents.isEmpty` cascade; regression covered by `test/app_navigation_flow_test.dart`).
- Avoid Firestore `array-contains + orderBy` (needs a composite index) → sort in memory.
- `AuthService.currentUser` wraps FirebaseAuth in try/catch → returns `null` in widget tests (never crash).
- **Stale `flutter_assets` → `Unable to load asset` at runtime**: Gradle's `mergeDebugAssets` will happily merge a *stale* Flutter asset dir, so `pubspec.yaml` can be correct and the APK still lacks the file. Symptom hit on 17 Nov: `assets/images/logo.png` threw `Asset not found` while the debug dir at `build/app/intermediates/flutter/debug/flutter_assets/` was still 3 days old (it was missing `assets/fonts/` too, so PDF export would have broken on device). Check `AssetManifest.json` there (`logo=True`?), then `flutter build apk --debug` — or `flutter clean` if it won't regenerate. The **release** dir was always fresh.
- Dashboard owns the single `GroupsBloc` (owe/pay card); `GroupsTab` reads it from above — don't create a second one.
- **Account deletion has three traps**, all in `AuthRemoteDataSource`: (1) always re-authenticate *before* any write, or a `requires-recent-login` failure lands after the data is gone; (2) group-expense rules call `get()` on the parent group and Firestore caps those at **10 per request**, so `_deleteSubcollection(..., batchSize: 10)` is used for expenses while plain subcollections use 400 (the write-batch limit is 500); (3) `profiles/{uid}` delete is guarded by an `exists` check — the rule reads `resource.data.uid`, which is an error (deny) on a missing document.

## 9. Key files
- `lib/app/{app_router.dart, router/route_names.dart, di/service_locator.dart, theme/}`
- `lib/core/{widgets/ (AppSnackbar, PrimaryButton/TextField), utils/currency_formatter.dart, services/firebase_service.dart (AuthService), constants/firebase_constants.dart (Google Web client ID), export/export_pdf.dart + assets/fonts/ (Unicode PDF font)}`
- `lib/features/dashboard/presentation/pages/dashboard_page.dart` (tabs, providers, owe/pay card)
- `lib/features/groups/…` (blocs, `group_balances.dart`, `split_calculator.dart`, 4 pages)
- `lib/features/wallet/…`, `lib/features/transactions/…`, `lib/features/budgets/…`
- `test/app_navigation_flow_test.dart` — full click-through regression (add balance, groups, expense save, dialogs).
- `test/login_page_test.dart` — only the tapped sign-in button spins; Google sign-in error mapping (cancel ≠ error, missing client ID explains itself).
- `test/splash_page_test.dart` — splash shows the GIF (not a spinner) on #0D132B and hands over to login after 2 s.
- `test/settings_account_test.dart` — reset-balance confirm/cancel/failure, delete-account password vs Google paths, and a rejected re-auth keeping the dialog open (needs a real `GoRouter`, because deletion ends at `context.go('/login')`).
- `lib/features/splash/presentation/pages/splash_page.dart`, `assets/images/{logo.png, splash_animation.gif}`, `android/…/res/{values/colors.xml, values-v31, values-night-v31, drawable*/launch_background.xml, drawable-xhdpi, drawable-xxxhdpi}`
