# Google Calendar Integration — Setup Guide

The app includes Google Calendar integration (WISH-0033) that lets users connect their Google Calendar and see events alongside tasks, finance, and custom events. This requires some Google Cloud Console configuration before it works.

## Prerequisites

- Access to the [Google Cloud Console](https://console.cloud.google.com/) for project `freek-personal-app`
- The app's Android signing key SHA-1 fingerprint

## Steps

### 1. Enable the Google Calendar API

1. Go to [APIs & Services → Library](https://console.cloud.google.com/apis/library?project=freek-personal-app)
2. Search for **Google Calendar API**
3. Click **Enable**

### 2. Configure OAuth Consent Screen

1. Go to [APIs & Services → OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent?project=freek-personal-app)
2. Choose **External** user type (or Internal if using Google Workspace)
3. Fill in the required fields:
   - App name: `Freek App`
   - User support email: your email
   - Developer contact: your email
4. Add the scope: `https://www.googleapis.com/auth/calendar.readonly`
5. Add your Google account as a test user (while in "Testing" publishing status)
6. Save

### 3. Create OAuth 2.0 Credentials

#### Android Client ID

1. Go to [APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials?project=freek-personal-app)
2. Click **Create Credentials → OAuth client ID**
3. Application type: **Android**
4. Package name: `nl.freekvandeven.personal_app`
5. SHA-1 certificate fingerprint — get it with:
   ```bash
   # Debug key:
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

   # Release key (use your actual keystore):
   keytool -list -v -keystore <your-release-keystore> -alias <your-alias>
   ```
6. Click **Create**

#### Web Client ID (required by google_sign_in on Android)

1. Click **Create Credentials → OAuth client ID**
2. Application type: **Web application**
3. Name: `Freek App Web Client`
4. No need to add authorized origins or redirect URIs for the Android flow
5. Click **Create**
6. Copy the **Client ID** — you'll need it in the next step

### 4. Update google-services.json

1. Go to [Firebase Console → Project Settings](https://console.firebase.google.com/project/freek-personal-app/settings/general/)
2. Under your Android app, click **google-services.json** to download the latest version
3. Replace `android/app/google-services.json` with the new file
4. Verify the `oauth_client` array now contains entries (it was previously empty)

Alternatively, manually add the Web Client ID to `google-services.json` under `oauth_client`:
```json
{
  "client_id": "<YOUR_WEB_CLIENT_ID>.apps.googleusercontent.com",
  "client_type": 3
}
```

### 5. (Optional) Configure for iOS

1. Create an **iOS** OAuth client ID in Google Cloud Console
2. Add the reversed client ID as a URL scheme in `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```
3. Update `GoogleService-Info.plist` if needed

### 6. Test

1. Build and run: `flutter run`
2. Go to Calendar page → tap the sync icon (⟳) → **Connect Google Calendar**
3. Sign in with a Google account that is added as a test user
4. Events from the primary calendar should appear with a blue Google icon

## Troubleshooting

- **Sign-in fails silently**: Check that the SHA-1 fingerprint matches your signing key and that the OAuth consent screen has your account as a test user.
- **Events don't appear**: Ensure the Google Calendar API is enabled and the `calendar.readonly` scope was approved.
- **PlatformException**: Verify `google-services.json` has the `oauth_client` entries and rebuild the app.

## Files Involved

- `lib/features/calendar/services/google_calendar_service.dart` — Google Sign-In + Calendar API calls
- `lib/features/calendar/providers/google_calendar_providers.dart` — Riverpod providers
- `lib/features/calendar/providers/calendar_providers.dart` — aggregates Google events with other sources
- `lib/features/calendar/pages/calendar_page.dart` — connect/disconnect UI
- `pubspec.yaml` — `google_sign_in` dependency
