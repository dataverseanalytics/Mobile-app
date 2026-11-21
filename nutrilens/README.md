# NutriLens

**Snap your plate. Know your food.** An AI calorie and macro tracker with worldwide phone-OTP sign-in.

## Run it

```bash
flutter pub get
flutter run            # Android/iOS device or emulator
flutter run -d chrome  # quick look in the browser (use phone view: F12 → Ctrl+Shift+M)
flutter test           # 24 unit + widget tests
```

Until Firebase is connected, the app runs in **demo mode**: sign-in works end to end, but no SMS is sent. Use code **123456**. A banner on the code screen says so.

## Turn on real SMS sign-in (Firebase, 200+ countries)

1. Create a project at console.firebase.google.com.
2. **Authentication → Sign-in method → Phone → Enable.**
3. Add your apps:
   - **Android:** package `com.nutrilens.nutrilens`. Add your SHA-1 and SHA-256 (`cd android && ./gradlew signingReport`). Download `google-services.json` to `android/app/`, and apply the Google Services Gradle plugin as Firebase shows.
   - **iOS:** bundle ID from Xcode. Download `GoogleService-Info.plist` to `ios/Runner/`, enable Push Notifications, and add the reversed client ID URL scheme.
   - **Or** run `dart pub global activate flutterfire_cli && flutterfire configure`, then pass `options: DefaultFirebaseOptions.currentPlatform` to `Firebase.initializeApp()` in `lib/main.dart`. This is also required for web.
4. During development, add test numbers under **Authentication → Phone → Phone numbers for testing**.
5. Before launch, set **SMS region policy** and **App Check** (Play Integrity / DeviceCheck) to prevent SMS abuse.

The app detects Firebase automatically at startup (`lib/main.dart`). No other code changes are needed.

## Fonts & design

- **Sora** for headlines and numbers; **Inter** for interface text. Both are bundled (SIL OFL).
- Warm paper `#F7F5F0`, ink `#14140F`, signature lime `#D4F25A`.
- Tokens live in `lib/core/theme/`. Light and dark themes are built from the same tokens.
- Photography: Unsplash (free licence), in `assets/images/`.

## Screens

| Area | Screens |
|---|---|
| Start | Splash · Welcome · Phone number (all countries, per-country validation) · OTP code (autofill, resend timer, errors) · Profile setup |
| Plan | 6-step onboarding → calculated plan → Paywall |
| Tabs | Today · Diary · Progress · Profile |
| Logging | Camera (photo/barcode) → Analysing → Result (edit portions) · Food search · Meal detail · Share card |
| Settings | Notifications · Edit profile · Daily targets (auto/custom) · Reminders · Subscription · Help & FAQ · Terms · Privacy · About · Account & data (sign out, delete account) |

**Navigation guards** (`authRedirect` in `lib/app/router.dart`):
- Signed-out users only reach public pages.
- New users go through setup and then onboarding.
- Returning users skip straight to Today.

**Persistence:** account, profile, meals, targets, reminders, weight log and notifications are saved on the device (`lib/data/local_store.dart`) and survive restarts.

## Backend connection

```bash
flutter run --dart-define=API_URL=http://localhost:8001   # see ../README.md
```

With `API_URL` set, the app uses the NutriLens API:
- phone sign-in goes through the backend
- tokens are stored in the phone's Keychain/Keystore
- changes are saved on the phone and synced to the server, even after periods offline
- AI scans happen on the server
- food search and barcodes come from the admin-managed database

Without it, everything runs on the device (demo code `123456`).

| Part | Where |
|---|---|
| API client (token refresh, errors) | `lib/data/api/api_client.dart` |
| Offline sync queue and server pull | `lib/data/api/sync_service.dart` |
| Backend sign-in | `lib/data/auth/api_auth_repository.dart` |
| Scan, barcode, search | `lib/data/scan_repository.dart` |

## Before launch

| Area | Status | To do |
|---|---|---|
| SMS sign-in | Backend OTP is in place (console SMS in dev) | Configure Twilio in `backend/.env` |
| AI scan | Backend mock scanner; OpenAI vision support is built | `SCAN_PROVIDER=openai` and `OPENAI_API_KEY` |
| Camera / barcode | Demo viewfinder | `camera`, `image_picker`, `mobile_scanner` |
| Payments | Razorpay Checkout built in (Android/iOS); server creates and verifies orders | Add Razorpay keys and webhook in `backend/.env`. iOS: Apple requires in-app purchase for digital features |
| Reminders | Settings saved and synced | `flutter_local_notifications` to schedule them |
| Legal text | Template | Lawyer review per market |
