# Image Picker — Native Permissions Reference

**Status:** v1.0
**Owner:** Repo owner (one-time native-config review + on-device verification)
**Linear:** TRI-298
**Last updated:** 2026-06-14

---

## 1. Purpose & scope

The avatar picker (TRI-24, `apps/mobile/lib/src/features/users/data/datasources/avatar_picker_datasource.dart`) lets a user set a profile photo by taking a photo (`pickFromCamera`) or choosing from the library (`pickFromLibrary`). Each path requires native OS permission declarations. This runbook is the reference for which declarations map to which picker method, why Android needs no manual library-permission entry, and the on-device verification the repo owner runs after merge.

**Note on repo state:** unlike at TRI-1, `apps/mobile/ios/` and `apps/mobile/android/` are committed to the repo (they are NOT gitignored — only build artifacts are). So these permission entries live in tracked files, not applied post-`flutter create`. This runbook documents the contract and the verification gate; the entries themselves are committed alongside it.

---

## 2. iOS — `apps/mobile/ios/Runner/Info.plist`

Two usage-description keys are required. Both are present after this PR:

| Key | Required by | Purpose string (current) |
|---|---|---|
| `NSCameraUsageDescription` | `pickFromCamera()` | "Tribely uses your camera to take a verification selfie." |
| `NSPhotoLibraryUsageDescription` | `pickFromLibrary()` | "Tribely uses your photo library so you can choose a profile photo." |

The `NSCameraUsageDescription` string predates this ticket (added for the selfie verification flow) and is reused for avatar capture — camera usage is camera usage. The exact wording is the repo owner's final call; both keys must be present with a plausible purpose string for App Store review and for the OS permission prompt to appear (a missing key causes a hard failure, not a denial).

Do NOT add `NSPhotoLibraryAddUsageDescription` — that key gates *saving* to the library; image_picker only reads.

---

## 3. Android — `apps/mobile/android/app/src/main/AndroidManifest.xml`

One permission is required and present:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

It sits inside `<manifest>`, above `<application>` (alongside the existing location permissions). Required by `pickFromCamera()`.

**Library access needs NO manual entry.** On Android 13+ (API 33+), `image_picker` uses the Photo Picker (`ACTION_PICK_IMAGES`), which requires no runtime storage permission — the `image_picker_android` plugin's manifest merger contributes whatever it needs. On older API levels the plugin also handles access without an app-declared storage permission for the pick-only flow. This is why `pickFromLibrary()` works on Android with no `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` declaration in this manifest.

### Conditional fallback (only if on-device verification proves it necessary)

The code contract (and `avatar_picker_datasource.dart`) says the manifest merger covers library access on the target API level, so no storage permission should be needed. IF — and only if — the on-device verification below shows "Choose from library" failing on a specific target API level, add as a documented fallback:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

Do NOT add this pre-emptively. It is a fallback, not a requirement.

---

## 4. On-device verification gate (repo owner runs post-merge)

Run on a physical device (or emulator with camera) on the target iOS and Android versions. All checks must pass before TRI-298 is closed.

**iOS:**
- [ ] Take photo: tap "Take photo" on the avatar picker → camera opens → capture → no crash; photo lands as avatar.
- [ ] Choose from library: tap "Choose from library" → library opens → select → no crash; photo lands as avatar.
- [ ] Decline camera permission (first prompt): tap "Take photo", deny → in-app banner shown (TRI-24 `AvatarPickerPermissionDenied{isPermanent:false}` path), NOT a crash.
- [ ] Permanent-deny camera (deny twice / Settings off): tap "Take photo" → banner with "Open Settings" affordance (`isPermanent:true` path), NOT a crash.
- [ ] Repeat the two denial checks for the photo-library permission.

**Android (target API — note the API level tested):**
- [ ] Take photo → no crash.
- [ ] Choose from library → no crash (confirms manifest merger covers library access — if this FAILS, apply the §3 `READ_MEDIA_IMAGES` fallback and re-test).
- [ ] Decline camera permission → in-app banner, NOT a crash.
- [ ] Permanent-deny camera → banner + "Open Settings", NOT a crash.

**Record completion** in the PR description, noting the iOS + Android versions tested and any deviation (e.g., if the §3 fallback was needed).

---

## 5. Notes

- No new env var, no `.env.example` change, no localization (English-only MVP).
- No automated native-permission lint (deferred — manual review per this runbook is sufficient at this stage).
- Copy wording for both usage strings is the repo owner's final call. A more general camera string ("...to take photos for your profile and verification") would cover both selfie + avatar; the current selfie-flavored string is retained to keep this PR minimal. Optional follow-up if the team wants the generalization.
