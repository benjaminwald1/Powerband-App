# Turning on Apple, Google and email sign-in

The app is wired for Firebase Authentication. Until you add a config file it runs in **local mode** (on-device profile only), so nothing breaks. These are the steps only you can do.

## 1. Firebase project (5 minutes)

1. Go to console.firebase.google.com, **Add project** (name it PowerBand; Google Analytics can stay off).
2. **Project settings > Your apps > Add app > iOS**. Bundle ID: `com.benjaminwald.powerband`. Download **GoogleService-Info.plist**.
3. Save it as `PowerBand/Resources/GoogleService-Info.plist` (it is git-ignored on purpose).
4. **Build > Authentication > Sign-in method**: enable
   - **Email/Password**
   - **Google**: pick a support email
   - **Apple**: enable it. For native iOS you don't need a Services ID.
5. **Authentication > Settings > Authorized domains**: the defaults are fine.

## 2. Apple capability

The app declares the *Sign in with Apple* entitlement (`PowerBand.entitlements`). The first time you build to a device with Xcode (Signing & Capabilities, Team set) Xcode adds the capability to your App ID. Required for Apple sign-in on a real phone.

## 3. Finish the Google redirect

```bash
./scripts/setup-auth.sh
```

This reads your plist and writes the URL schemes into the git-ignored `Local.xcconfig`, then regenerates the project.

## 4. Test

Run on a device or simulator, then on the first screen try Apple, Google and email. In Firebase console > Authentication > Users you will see the accounts.

## What the app does with accounts

- Sessions never leave the phone. Firebase only stores the sign-in identity (uid, email, name, provider).
- **Sign out** ends the Firebase session; sessions stay on the phone.
- **Delete account** re-authenticates, revokes the Apple token if needed, deletes the Firebase user, then wipes all local data. This satisfies Apple's in-app account deletion rule.
- Password reset sends Firebase's email.

## Before you ship

- Customize the email templates under Authentication > Templates (sender name, links).
- The website privacy policy already describes cloud sign-in; keep it in sync with whatever you enable.
- Firebase Authentication is a Google service: add it to your App Store privacy answers as *Contact info (email, name)* and *Identifiers (user ID)*, collected for *App functionality*, linked to the user, not used for tracking. If you never turn on sign-in, the answer stays "Data not collected".
