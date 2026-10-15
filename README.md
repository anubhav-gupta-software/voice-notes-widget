# Voice Notes

A short recording for a friend. The latest one sits on their Home Screen with their photo and a waveform, and tapping it opens the app and plays the note.

You can try the whole thing on one iPhone by recording a note for yourself. Two phones can pass notes over the same Wi-Fi with no account, or through a small sync server when they are apart. Nothing in the default setup needs an API key.

## What you can do

- Record up to 30 seconds, listen back, retake, and send.
- Create a profile with a name, a photo, and a 6-character invite code.
- Add a friend by typing their code, or tap **Pair nearby** on both phones.
- Read an inbox of notes you received and notes you kept for yourself.
- Put a Home Screen widget (small or medium) or a Lock Screen widget on the phone. It shows the newest note you have not heard, otherwise the newest one.
- Tap the widget. Voice Notes opens and starts playback. A widget cannot play audio on its own, so the tap is what starts it.

Notes stay on the phone until you send one. Nearby delivery uses Multipeer Connectivity on the local network. The optional server is a single Python file with no packages.

## What you need

- A Mac with Xcode 15 or later. Xcode 16 is a comfortable match for this project.
- An iPhone running iOS 17 or later.
- A free Apple ID. A paid Apple Developer Program membership is not required to install and run the app from Xcode.

The app is iPhone only, and it stays in portrait.

## Open the project

Clone the repo and open `VoiceNotes.xcodeproj`. That project is already generated and checked in.

`project.yml` describes the same targets for [XcodeGen](https://github.com/yonaskolb/XcodeGen). You only need it if you want to regenerate the project after moving files around:

```bash
brew install xcodegen
xcodegen generate
```

There are two targets:

| Target | Bundle id | Role |
| --- | --- | --- |
| VoiceNotes | `software.anubhavgupta.voicenotes` | The app |
| VoiceNotesWidget | `software.anubhavgupta.voicenotes.widget` | Home Screen and Lock Screen widget |

They share an App Group, `group.software.anubhavgupta.voicenotes`, so the widget can read the latest note. See [If the App Group entitlement will not sign](#if-the-app-group-entitlement-will-not-sign) if Xcode refuses that.

## Install it on an iPhone with a free Apple ID

1. Install Xcode from the Mac App Store and open it once so it can finish installing the extra components.
2. In Xcode, open **Settings → Accounts** and sign in with your Apple ID. Xcode calls this a **Personal Team**. That is the free account.
3. Open `VoiceNotes.xcodeproj`.
4. Select the **VoiceNotes** scheme and your iPhone as the run destination. Plug the phone in, unlock it, and tap Trust if the phone asks.
5. Select the **VoiceNotes** target, then **Signing & Capabilities**. Check **Automatically manage signing**. Choose your Personal Team. Do the same for the **VoiceNotesWidget** target. Both targets have to use the same team.
6. If Xcode says the bundle id is not available, change it to something unique, such as `com.yourname.voicenotes`. Change the widget id to that same prefix plus `.widget`. If you change the App Group too, update it in all of these so they match:
   - `Config/AppGroup.entitlements`
   - `Shared/AppGroup.swift` (`AppGroup.identifier`)
7. Press **Run**. The first build takes a while. On the iPhone, if iOS says the developer is untrusted, open **Settings → General → VPN & Device Management**, trust your Apple ID, and run again from Xcode.
8. Allow the microphone when asked. Allow Local Network as well if you want notes to move between phones on the same Wi-Fi.
9. Make a profile, record a note with **Me** selected, and send it. It shows up in the inbox.
10. Leave the app. Touch and hold the Home Screen, tap **+**, search for **Voice Notes**, and add **Latest Note**. The note you just kept should be there. Tap it. The app opens and plays it.

A free Personal Team is enough for this, including the widget extension. Apple's current limits for that kind of account are:

- You can register up to 10 App IDs, and they expire after 7 days. This project uses two: the app and the widget.
- You can register up to 3 devices, and those registrations expire after 7 days.
- You can have up to 3 apps installed this way on a device.
- The provisioning profile expires 7 days after Xcode creates it. When the app stops opening, plug the phone back in and press Run again.

Those numbers come from Apple's [developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/). They can change.

## If the App Group entitlement will not sign

Apple's [supported capabilities table](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) currently lists **App Groups** for a free Apple Developer account, which is why the entitlement is on by default. The widget only sees real notes through that group.

If Xcode still reports that your Personal Team does not support App Groups:

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. In that file, set `CODE_SIGN_ENTITLEMENTS` to empty:

   ```
   CODE_SIGN_ENTITLEMENTS =
   ```

3. Build again. The app installs. Recording, the inbox, friends, nearby delivery, and the sync server all still work. The widget installs too, but it stays on its empty state until the entitlement is signed, because the extension cannot read the app's files without the group.

`Config/Local.xcconfig` is gitignored.

When the entitlement does sign, Xcode's automatic signing registers `group.software.anubhavgupta.voicenotes` for both targets. Record or play a note after that so the app writes a fresh snapshot.

## Two phones

On the same Wi-Fi:

1. Install the app on both phones and create a profile on each.
2. Either enter each other's codes under **Friends**, or tap **Pair nearby** on both phones within the same minute and a half.
3. On one phone, pick the friend, record, and send.
4. The other phone gets the note in the inbox, and its widget updates to that note.

Pairing is how you connect without typing. After the phones have exchanged profiles once, later notes deliver whenever Nearby is on and they are on the same network. The phone with the alphabetically earlier code invites, and the other accepts, so they do not both try to connect at once.

Nearby traffic uses Multipeer Connectivity with encryption required. It is still local-network traffic between two phones you chose to pair. There is no account behind it.

## Optional sync server

Use this when the phones are not on the same Wi-Fi. It does not need Firebase, CloudKit, or an API key.

On a computer the phones can reach:

```bash
python3 backend/server.py
```

That listens on port 8787. To require a token:

```bash
python3 backend/server.py --token something-secret
```

Or set `VOICENOTES_TOKEN`. Find the computer's address on your network, for example `192.168.1.20`. On each phone, open **You** (the profile button) and set the sync server to:

```text
http://192.168.1.20:8787
```

Put the token in the second field if you started the server with one. Tap **Save server**. Pull to refresh the inbox, or leave the app and come back, and it will push notes that have not been uploaded and pull notes addressed to your code.

The app allows plain HTTP only for local-network addresses (`NSAllowsLocalNetworking`). If the server is on the public internet, put HTTPS in front of it and use an `https://` address. Do not leave an open server on the internet. Pass `--token` if anyone besides your own Wi-Fi can reach it.

Notes are stored as JSON files in `backend/data/`, which is gitignored. The phone skips notes it already has.

```text
GET  /health
POST /v1/notes
GET  /v1/notes?recipient=CODE&since=UNIX_SECONDS
```

`POST` body is JSON: `id`, `senderCode`, `senderName`, optional `senderPhotoBase64`, `recipientCode`, `createdAt` (seconds since 1970), `duration`, `waveform`, and `audioBase64`. Sending the same `id` again is a no-op. If a token is set, send `Authorization: Bearer <token>`.

Leave the address blank and the app never talks to a server.

## What needs a paid developer account

Installing from Xcode with a Personal Team does not. These do:

| Thing | In this project? |
| --- | --- |
| TestFlight and the App Store | Not until you ship it. Steps are below. |
| Push notifications | Not used. |
| iCloud and CloudKit | Not used. |
| Sign in with Apple | Not used. |
| App Groups, if your Personal Team rejects the entitlement | The fallback above keeps the app installable. A paid membership is the dependable way to turn widget sharing back on. |

Background audio is not enabled. Playback runs while the app is open, which is what a widget tap does.

## Move it to TestFlight later

TestFlight requires the [Apple Developer Program](https://developer.apple.com/programs/) (paid).

1. Enroll, then in Xcode pick that team for **both** the app and the widget.
2. Use a bundle id you control. Register the App Group `group.software.anubhavgupta.voicenotes` (or your own id, kept in sync with the entitlements file and `AppGroup.swift`) and confirm it is on both targets under **Signing & Capabilities**.
3. Set the version and build number if you are uploading again. The project starts at 1.0 (1).
4. Choose **Any iOS Device (arm64)** as the destination. **Product → Archive**.
5. In the Organizer, **Distribute App → App Store Connect → Upload**.
6. In App Store Connect, create the app record with the same bundle id. Export compliance should already be answered: `ITSAppUsesNonExemptEncryption` is false. The app does not add its own encryption on top of HTTPS and Multipeer.
7. Open **TestFlight**. Internal testers (members of your team, up to 100) can install without a beta review. External testers go through a short Beta App Review.
8. Testers install Apple's TestFlight app, accept the invite, and install Voice Notes. A TestFlight build expires after 90 days.

The sync server is still yours to run. TestFlight does not host the audio.

## Layout

```text
VoiceNotes.xcodeproj    app + widget, shared scheme
project.yml             XcodeGen spec, if you want to regenerate
Config/                 xcconfig and the App Group entitlement
Shared/                 models, colors, waveform, App Group snapshot
VoiceNotes/             SwiftUI app, recorder, inbox, nearby, remote sync
VoiceNotesWidget/       widget extension
backend/server.py       optional sync server
```

Recordings live in Application Support on the phone (`audio/<id>.m4a` plus JSON for the profile, friends, and notes). The widget snapshot is `widget-payload.json` in the App Group container.

## Permissions

- **Microphone** — recording.
- **Local Network and Bonjour** (`_voicenote._tcp` and `_voicenote._udp`) — finding a friend nearby.
- **Photos** — only the pictures you pick for a profile or a friend. The picker does not need broad photo-library access.

Photos and recordings stay on the device unless you send a note to a nearby friend or you filled in a sync server.
