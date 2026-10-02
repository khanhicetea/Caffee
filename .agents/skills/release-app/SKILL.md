---
name: release-app
description: Release Caffee end to end on the dev machine - archive, Developer ID export, notarize, staple, DMG, Sparkle signature, then update the website appcast and pages. Use when the user asks to release, ship, publish, or cut a new version of Caffee.
---

# Release Caffee

Runs locally (no CI). The heavy lifting is `scripts/release.sh`; this skill drives it and then updates the website.

Prerequisites already set up on this Mac: `Developer ID Application` cert in the login keychain, notarytool keychain profile `icetea-notary`, `create-dmg` (npm), Sparkle `sign_update` (`~/Code/tools/sign_update`, private key in the keychain).

## Instructions

1. **Decide the version**
   - If the user gave one (`1.31.0`), pass `--version 1.31.0`. The script bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` (build = major*10000 + minor*100 + patch, e.g. 1.31.0 -> 13100).
   - If not given, release the version already in the project (`grep MARKETING_VERSION Caffee.xcodeproj/project.pbxproj`) and confirm with the user if it equals the latest `<sparkle:shortVersionString>` already in `web/appcast.xml` (that version was already shipped).

2. **Run the script** (takes several minutes; run it in the background and wait for the notification)
   ```bash
   scripts/release.sh --version X.Y.Z
   ```
   - It archives, exports with Developer ID, notarizes + staples the app, builds and signs the DMG, notarizes + staples the DMG, then signs it for Sparkle. Output lands in `build/vX.Y.Z/`.
   - Use `scripts/release.sh --dry-run` first when the user only wants to check that the build/export/DMG still work (no Apple submission, no Sparkle signature).
   - It refuses to run if `build/vX.Y.Z/` already exists; never delete that folder to get around it, ask the user.
   - If notarization is rejected, the script exits and writes the Apple log to `build/vX.Y.Z/notary-<app|dmg>-log.json`. Read it and report the issues; do not retry blindly.
   - `swift-format` runs as a build phase and may modify source files; mention any such diff.

3. **Read `build/vX.Y.Z/release-info.json`** for `version`, `build`, `download_url`, `sparkle_ed_signature`, `length`, `sha256`, `pub_date`, `previous_tag`.

4. **Release notes**
   - Use the notes the user provided; otherwise draft them from `git log <previous_tag>..HEAD` (and the working tree if uncommitted changes went into the build). Keep them short, user-facing.
   - The website notes are Vietnamese. Write English notes only if the user asks.

5. **Update `web/appcast.xml`** - add a new `<item>` at the top of `<channel>`, above the newest existing item:
   ```xml
   <item>
     <title>Version X.Y.Z</title>
     <sparkle:version>BUILD</sparkle:version>
     <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
     <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
     <pubDate>PUB_DATE</pubDate>
     <enclosure
       url="DOWNLOAD_URL"
       sparkle:edSignature="SPARKLE_ED_SIGNATURE"
       length="LENGTH"
       type="application/octet-stream"
     />
     <description><![CDATA[
       <h2>Có gì mới</h2>
       <ul>
         <li>...</li>
       </ul>
     ]]></description>
   </item>
   ```

6. **Update `web/index.html`**
   - Hero button: change both `href="/download.html?v=X.Y.Z"` and the text `Tải về vX.Y.Z`.
   - In `<div class="releases-list">`, add as the first child:
     ```html
     <div class="release">
         <h3>vX.Y.Z</h3>
         <div class="checksum">
             sha256:
             SHA256
         </div>
         <ul>
             <li>...</li>
         </ul>
     </div>
     ```

7. **Update `web/download.html`**
   - The `<meta http-equiv="refresh" ...>` URL, the "Tải về ngay" link `href`, and `<div class="version">vX.Y.Z</div>`; all use `DOWNLOAD_URL` / `vX.Y.Z`.

8. **Verify** before reporting: `grep -rn "<previous version>" web/` should only hit older release entries, and `xmllint --noout web/appcast.xml` must pass.

9. **Summary and hand-off**
   - Show version, DMG path, sha256, and the files changed.
   - Do not commit, push, tag, create the GitHub release, or deploy `web/` unless the user asks. Remind them of the remaining manual steps:
     - Upload `build/vX.Y.Z/Caffee-vX.Y.Z.dmg` to the GitHub release for tag `vX.Y.Z` (the appcast URL points there, so upload before deploying the web files).
     - Deploy `web/`.
     - Commit as `release vX.Y.Z` (project convention).
