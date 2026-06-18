# Releasing to Google Play (automated via GitHub Actions)

Package: `com.ivoexp.habits`. The workflow `.github/workflows/release.yml` builds a
**signed AAB** and uploads it to the **internal** track when you push a `v*` tag.

> ⚠️ **First release of THIS package must be manual.** Google blocks the Play
> Developer API from creating the very first release of a brand-new package name.
> You already have a *different* app in the console — that doesn't count. You must
> create `com.ivoexp.habits` in Play Console and upload one signed AAB by hand.
> After that, the CI auto-upload works for every subsequent version.

---

## One-time setup

### 1. Keystore (you have one)
Make sure your upload keystore (`.jks`) and its passwords/alias are handy. The same
keystore must be used for the first manual AAB and for CI — Play rejects mismatched
signatures. (If this app is enrolled in Play App Signing, the *upload* key is what
matters here.)

For local release builds, copy `android/key.properties.example` →
`android/key.properties` and fill in real values (it is gitignored).

### 2. Create the app + first manual release
1. Play Console → **Create app** → set name, default language, app/game, free/paid.
2. Build a signed AAB locally:
   ```
   flutter build appbundle --release
   # output: build/app/outputs/bundle/release/app-release.aab
   ```
3. Play Console → your app → **Testing → Internal testing → Create release** →
   upload the AAB → roll out. (Complete the required store-listing / content forms.)

### 3. Service account for the API
1. Play Console → **Setup → API access** → link or create a Google Cloud project.
2. Create a **service account** (Google Cloud → IAM → Service Accounts), create a
   **JSON key**, download it.
3. Back in Play Console → **Users & permissions** → invite the service-account email →
   grant at least **Release to testing tracks** (and **Release to production** if you
   want the `production` track). App-level or account-level is fine.
   - If you already made a service account for your other app, just grant it access to
     this app too — no need for a new one.

### 4. GitHub repo + secrets
This repo currently has **no remote**. Create one and push, e.g.:
```
gh repo create habits --private --source=. --remote=origin --push
# or: create it on github.com, then
#   git remote add origin git@github.com:<you>/habits.git
#   git push -u origin finish-cleanup
```
Then add these **Actions secrets** (repo → Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of your `.jks` — see below |
| `ANDROID_KEYSTORE_PASSWORD` | keystore (store) password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | the **entire contents** of the service-account JSON |

Make the base64 (PowerShell):
```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\upload.jks")) > keystore.b64.txt
```
Paste the contents of `keystore.b64.txt` as the secret value.

---

## Cutting a release
1. Bump `version:` in `pubspec.yaml` if you want a new versionName (the CI also takes
   the name from the tag). The **versionCode** is auto-set to
   `VERSION_CODE_OFFSET (100) + workflow run number`, so it always increases.
2. Tag and push:
   ```
   git tag v1.0.1
   git push origin v1.0.1
   ```
3. Watch **Actions** → "Release to Google Play". On success the build lands on the
   **internal** track. Promote to closed/open/production from Play Console (or run the
   workflow manually with a different `track`).

## Notes
- First CI run will fail at the upload step until the manual first release (step 2) and
  service-account permissions (step 3) are done — the AAB still builds and is saved as an
  artifact, so you can grab it from the run.
- `versionName` comes from the tag (`v1.0.1` → `1.0.1`). Keep tags as `vX.Y.Z`.
