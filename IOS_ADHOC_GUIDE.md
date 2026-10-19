# TT Piciulin on iPhone — Ad Hoc guide

Only the iPhones you register can install the app. Builds run on Codemagic
(a Mac in the cloud) and reach your friends through Firebase App Distribution.

iPhone app ID (bundle ID): `com.andreazito.ttpiciulin`

---

## 1. Get each friend's iPhone ID (UDID)

With the iPhone connected by cable to your Windows PC:

1. Install **iTunes** for Windows (Microsoft Store or apple.com).
2. Connect the iPhone, unlock it and tap **Trust**.
3. In iTunes click the phone icon → **Summary**.
4. Click **Serial Number** once: it changes to **UDID**. Right-click → **Copy**.
5. Save it with the friend's name, e.g. `Marco — 00008110-001A2B3C4D5E6F7G`.

(Later friends can also register remotely through Firebase, see step 10.)

## 2. Join the Apple Developer Program

1. Go to developer.apple.com/programs → **Enroll**, sign in with your Apple ID
   (two-factor authentication must be on). Enroll as an **Individual**.
2. Pay the yearly fee. Approval can take up to a couple of days.

## 3. Register the app and the iPhones (developer.apple.com → Account)

1. **Certificates, IDs & Profiles → Identifiers → +** → App IDs → App.
   Description `TT Piciulin`, Bundle ID **Explicit**: `com.andreazito.ttpiciulin`.
   No capabilities needed → Register.
2. **Devices → +** → Platform iOS, a name (e.g. "Marco iPhone") and the UDID.
   Repeat for each friend.

## 4. Create an App Store Connect API key (lets Codemagic sign the app)

1. appstoreconnect.apple.com → **Users and Access → Integrations →
   App Store Connect API → Team Keys → +**.
2. Name `Codemagic`, access **App Manager** → Generate.
3. **Download the .p8 file** (it can be downloaded only once) and note the
   **Key ID** and the **Issuer ID** shown on that page.

## 5. Create the certificate private key (on your PC)

In PowerShell:

```
ssh-keygen -t rsa -b 2048 -m PEM -f "$HOME\Desktop\ios_distribution_private_key"
```

Press **Enter twice** when asked for a passphrase (leave it empty).
This creates `ios_distribution_private_key` on the Desktop. Keep it private:
Codemagic uses it to create and reuse your distribution certificate.

## 6. Set up Firebase App Distribution

1. console.firebase.google.com → **Add project** `TT Piciulin` (Analytics not needed).
2. **Add app → iOS**, bundle ID `com.andreazito.ttpiciulin`, nickname `TT Piciulin`.
   Skip the config-file and SDK steps (not needed for App Distribution).
3. Project settings (cog) → **General** → your iOS app → copy the **App ID**
   (looks like `1:1234567890:ios:abc123…`).
4. **App Distribution → Get started → Testers & Groups → Add group** named
   `friends` (its alias must be `friends`). Add your friends' emails.
5. Project settings → **Service accounts** → the link to Google Cloud →
   **Create service account** → role **Firebase App Distribution Admin** → Done.
   Then on the account: **Actions → Manage keys → Add key → Create new key → JSON**.
   Keep the downloaded JSON file private.

## 7. Put the app on GitHub (private)

1. Create a GitHub account if needed, then **New repository** →
   name `tt-piciulin`, **Private**, no README.
2. In PowerShell (Git must be installed: `git --version`):

```
cd "C:\dev\Table tennis App\app"
git init
git add .
git commit -m "TT Piciulin"
git branch -M main
git remote add origin https://github.com/<your-user>/tt-piciulin.git
git push -u origin main
```

## 8. Set up Codemagic

1. codemagic.io → sign up with GitHub → **Add application** → GitHub →
   `tt-piciulin` → Flutter → it finds `codemagic.yaml`.
2. In the app → **Environment variables**, add (tick **Secret** for each):

| Variable | Group | Value |
|---|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | apple | Issuer ID (step 4) |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | apple | Key ID (step 4) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | apple | whole content of the `.p8` file |
| `CERTIFICATE_PRIVATE_KEY` | apple | whole content of `ios_distribution_private_key`, including the BEGIN/END lines |
| `FIREBASE_SERVICE_ACCOUNT` | firebase | whole content of the JSON key (step 6) |
| `FIREBASE_IOS_APP_ID` | firebase | App ID (step 6) |

Open files with Notepad to copy their content.

## 9. Build and send

1. Codemagic → **Start new build** → branch `main`, workflow **iPhone Ad Hoc**.
2. About 15–20 minutes. If it fails, download the log and send it to Claude.
3. When it succeeds, Firebase emails everyone in the `friends` group.

**Your friend, on the iPhone:**
1. Opens the email **in Safari**, accepts the invitation and follows the steps
   to install the app (Firebase may ask to sign in with a Google account).
2. Opens TT Piciulin: iOS says **Developer Mode** is required.
3. **Settings → Privacy & Security → Developer Mode → On** → restart →
   confirm **Turn On** after the restart. Now the app opens.

## 10. Adding someone later

1. Get their UDID: by cable (step 1), or add them to the `friends` group,
   distribute the latest release to them in Firebase, and when they accept they
   tap **Register device**; Firebase emails you the UDID.
2. developer.apple.com → **Devices → +** (step 3).
3. developer.apple.com → **Profiles** → delete the existing **Ad Hoc** profile
   for TT Piciulin (the next build creates a new one including the new iPhone).
4. Start a new build in Codemagic.

## Updates

Change the code, then:

```
git add .
git commit -m "Update"
git push
```

and start a new build in Codemagic. Firebase emails your friends to install
the new version; their data is kept.

## Once a year

The membership, the certificate and the Ad Hoc profile last a year. Renew the
membership, delete the expired profile and start a new build. If the
certificate expired too, Codemagic creates a new one on the next build.
