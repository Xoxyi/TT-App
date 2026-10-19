# TT Piciulin on Google Play — private (internal testing)

The app is visible only to the people on your list (up to 100), who install
it from the Play Store. It never appears in Play Store search.

Android app ID: `com.andreazito.ttpiciulin` (permanent once uploaded).

---

## 1. Create your upload key (once)

Play only accepts apps signed with your own key. In PowerShell:

```
mkdir "C:\dev\Table tennis App\keys"
& "C:\dev\jdk\jdk-17.0.20.1+1\bin\keytool.exe" -genkey -v `
  -keystore "C:\dev\Table tennis App\keys\upload-keystore.jks" `
  -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

(This is the Java that Flutter uses; `flutter doctor -v` shows it.)

Choose a password and answer the questions (name, city…; anything sensible).
**Back up `upload-keystore.jks` and the password** (e.g. a password manager):
you need them for every update. The `keys` folder is outside the app folder,
so it never ends up on GitHub.

## 2. Tell the build where the key is

Copy `android\key.properties.example` to `android\key.properties` and fill in
your password (twice: with PKCS12 the store and key password are the same). `key.properties` is
ignored by Git.

## 3. Build the app bundle

```
cd "C:\dev\Table tennis App\app"
flutter build appbundle --release
```

The file is `build\app\outputs\bundle\release\app-release.aab`.

## 4. Create the app in Play Console

play.google.com/console → **Create app**:
- App name `TT Piciulin`, default language as you prefer
- **App**, **Free**
- Tick the declarations → **Create app**

## 5. Add your testers

Left menu → **Test and release → Testing → Internal testing** → **Testers** tab:
1. **Create email list** → name `Amici` → add the **Google accounts** your
   friends use on their phones (usually Gmail addresses) → Save.
2. Tick the list → **Save**.

## 6. Upload the first release

Same page → **Releases** tab (or **Create new release**):
1. App signing: accept **Google-managed app signing** (Play App Signing).
2. Upload `app-release.aab`.
3. Release name (e.g. `1.0.0`) and short notes → **Next** → **Save and publish**
   (or **Start rollout to Internal testing**).

You can do this before finishing the store listing and the questionnaires.
If Play Console still asks for something, see "If Play asks" below.

## 7. Send the invite link

Internal testing → **Testers** tab → **Copy link** (the join link).
Send it to your friends. On their phone, signed in with the Google account
you added:
1. Open the link → **Accept invitation** → **Download it on Google Play**.
2. Install as usual. The first time it can take a little while to appear, and
   the name may be temporary for up to 48 hours.

**Anyone who installed the APK you sent before must uninstall it first**
(it was signed with a different key). This deletes the app's data on that
phone; FITeT results come back on the next update. The same applies to your
own phone: install the Play version and keep using that one.

## Updates

1. Raise the version in `pubspec.yaml`, e.g. `version: 1.0.1+2`
   (the number after `+` must go up for every upload).
2. `flutter build appbundle --release`
3. Internal testing → **Create new release** → upload → **Save and publish**.

Your friends get the update from the Play Store like any other app.

## Adding or removing people

Internal testing → Testers → edit the `Amici` list. Removed people stop
receiving updates.

## If Play asks for more

Depending on the account, Play Console may ask you to complete some items in
**Dashboard → Set up your app**. Suggested answers for TT Piciulin:
- **App access:** all functionality available without special access.
- **Ads:** no ads.
- **Data safety:** the app doesn't collect or share user data (it only reads
  public FITeT pages and keeps everything on the phone).
- **Privacy policy:** a short page saying exactly that (Claude can write it).
- **Target audience:** adults/teens as appropriate for your friends.
