# Release Guide for Caffee

This document describes how to set up Sparkle auto-updates and release new versions.

## One-Time Setup: Build Sparkle Tools & Generate Signing Keys

Sparkle uses EdDSA (Ed25519) keys to sign and verify updates. You need to generate these keys once and store them securely.

### 0. Build Sparkle Tools (one-time)

First, build the signing tools from the Sparkle source:

```bash
cd ~/Library/Developer/Xcode/DerivedData/Caffee-*/SourcePackages/checkouts/Sparkle
xcodebuild -project Sparkle.xcodeproj -scheme "generate_keys" -configuration Release build
xcodebuild -project Sparkle.xcodeproj -scheme "sign_update" -configuration Release build
```

The built tools will be at:
```
~/Library/Developer/Xcode/DerivedData/Sparkle-*/Build/Products/Release/generate_keys
~/Library/Developer/Xcode/DerivedData/Sparkle-*/Build/Products/Release/sign_update
```

**Tip:** Copy these to a permanent location for easier access:
```bash
mkdir -p ~/bin
cp ~/Library/Developer/Xcode/DerivedData/Sparkle-*/Build/Products/Release/generate_keys ~/bin/
cp ~/Library/Developer/Xcode/DerivedData/Sparkle-*/Build/Products/Release/sign_update ~/bin/
```

### 1. Generate Keys

```bash
~/Library/Developer/Xcode/DerivedData/Sparkle-*/Build/Products/Release/generate_keys
# Or if you copied to ~/bin:
~/bin/generate_keys
```

This will:
- Create a private key and store it in your **Keychain** (under "Sparkle Private Key")
- Print the **public key** to the terminal

**IMPORTANT:**
- The private key is stored in your macOS Keychain - back up your Keychain or export this key securely
- Never share the private key
- If you lose the private key, users won't be able to update to new versions signed with a different key

### 2. Update Info.plist with Public Key

Copy the public key output and update `Caffee/Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

Replace `PLACEHOLDER_PUBLIC_KEY` with your actual public key (a base64-encoded string).

### 3. Rebuild the App

After updating the public key, rebuild the app:

```bash
xcodebuild build -scheme Caffee
```

---

## Releasing a New Version

### 1. Update Version Numbers

In Xcode project settings or `project.pbxproj`:
- Update `MARKETING_VERSION` (e.g., `1.17.0` → `1.18.0`)
- Update `CURRENT_PROJECT_VERSION` if needed

### 2. Build Release

```bash
xcodebuild build -scheme Caffee -configuration Release
```

The built app will be at:
```
~/Library/Developer/Xcode/DerivedData/Caffee-*/Build/Products/Release/Caffee.app
```

### 3. Create DMG

Create a distributable DMG file:

```bash
# Create a temporary folder
mkdir -p /tmp/caffee-release
cp -R ~/Library/Developer/Xcode/DerivedData/Caffee-*/Build/Products/Release/Caffee.app /tmp/caffee-release/

# Create DMG
hdiutil create -volname "Caffee" -srcfolder /tmp/caffee-release -ov -format UDZO Caffee-X.Y.Z.dmg

# Clean up
rm -rf /tmp/caffee-release
```

### 4. Sign the Update

Sign the DMG with Sparkle's signing tool:

```bash
~/Library/Developer/Xcode/DerivedData/Sparkle-*/Build/Products/Release/sign_update /path/to/Caffee-X.Y.Z.dmg
# Or if you copied to ~/bin:
~/bin/sign_update /path/to/Caffee-X.Y.Z.dmg
```

This will output something like:
```
sparkle:edSignature="XXXXXX..." length="12345678"
```

Save both the **signature** and **file size**.

### 5. Upload DMG to GitHub Releases

1. Go to https://github.com/khanhicetea/Caffee/releases
2. Create a new release with tag `vX.Y.Z`
3. Upload `Caffee-X.Y.Z.dmg`
4. Note the download URL (usually `https://github.com/khanhicetea/Caffee/releases/download/vX.Y.Z/Caffee-X.Y.Z.dmg`)

### 6. Update appcast.xml

Edit `web/appcast.xml` and add a new `<item>` at the top of the channel (or update the existing one):

```xml
<item>
  <title>Version X.Y.Z</title>
  <sparkle:version>BUILD_NUMBER</sparkle:version>
  <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
  <pubDate>DAY, DD MON YYYY HH:MM:SS +0700</pubDate>
  <enclosure
    url="https://github.com/khanhicetea/Caffee/releases/download/vX.Y.Z/Caffee-X.Y.Z.dmg"
    sparkle:edSignature="SIGNATURE_FROM_SIGN_UPDATE"
    length="FILE_SIZE_IN_BYTES"
    type="application/octet-stream"
  />
  <description><![CDATA[
    <h2>What's New</h2>
    <ul>
      <li>Feature 1</li>
      <li>Bug fix 2</li>
    </ul>
  ]]></description>
</item>
```

Replace:
- `X.Y.Z` with the version number
- `BUILD_NUMBER` with `CURRENT_PROJECT_VERSION` from Xcode
- `SIGNATURE_FROM_SIGN_UPDATE` with the signature from step 4
- `FILE_SIZE_IN_BYTES` with the length from step 4
- `pubDate` with the current date in RFC 2822 format

### 7. Deploy appcast.xml

Push the updated `web/appcast.xml` to your website at `https://caffee.khanhicetea.com/appcast.xml`.

### 8. Update Website

Update `web/index.html`:
- Change the download button version
- Add release notes to the Release Notes section
- Add checksum: `shasum -a 256 Caffee-X.Y.Z.dmg`

---

## Verification

After releasing:

1. Run the old version of the app
2. Click "Check for Updates..." in the menu
3. Sparkle should show the update dialog with the new version
4. Test the full update flow

---

## Troubleshooting

### "No updates available" when there should be

- Check that `appcast.xml` is accessible at the URL in Info.plist
- Verify the version in appcast.xml is higher than the current app version
- Check the signature is correct

### Signature verification failed

- Make sure you're using the same private key that matches the public key in Info.plist
- Re-sign the DMG and update appcast.xml

### Keys not found

If `generate_keys` says a key already exists:
```bash
~/bin/generate_keys -p  # Print existing public key
```

To export the private key for backup:
```bash
~/bin/generate_keys -x private_key_backup.txt
```

To import a private key on a new machine:
```bash
~/bin/generate_keys -f private_key_backup.txt
```
