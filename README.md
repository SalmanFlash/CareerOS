# CareerOS

**Work in progress.** The local planner and public internship search have been tested. Independent Gmail OAuth and scanning have automated regression coverage, including Windows credential encryption. Real Google authorization and mailbox scanning still need verification with the user's configured client. A separate static phone preview is built by GitHub Actions; physical-phone installation and device sync remain unverified.

Personal Flutter Web career planner. The first milestone runs entirely on your device. It needs no sign-in, API key, billing account or hosted service.

## Open the Windows preview

Double-click **Start CareerOS.cmd** and open **http://127.0.0.1:4173** in Edge or Chrome. Keep that address for future visits so the browser can find your saved data. If the preview is already running, open the address directly.

Select **Mauqay → Listing add karo**, enter a title and original HTTPS listing link, then choose **Mere saath karo** on Aaj. Work through the steps, save a note, and mark the mission complete. The Progress tab records your result. Two practice listings are marked DEMO and tracked separately. Completing a mission records your self-report. It does not submit an application.

The controls at the top right switch between Roman Urdu and English and enable Exam Mode for seven days. Missions can be renamed, paused, resumed, postponed to the next Pakistan calendar day or skipped. Local browser storage retains notes, language and checkpoints. Clearing site data removes that record. After the first online load finishes caching, this address can reopen offline in the same browser profile.

In **Aaj → FAST notice add karo**, choose the Karachi or Lahore inbox, enter the email subject and required action, and optionally enter the stated deadline as YYYY-MM-DD (Pakistan time). This manual workflow stores those fields in your browser. Active notices due by tomorrow take priority over routine tasks, including in Exam Mode. Use Progress → Edit notice to correct a date or action. Postponing changes the planned day while preserving the original deadline.

## Independent Gmail connection

Open **Settings → Open Gmail setup** in Edge or Chrome on Windows. Follow the linked Google guide to enable Gmail API, add both university addresses as test users and download a Desktop app OAuth client JSON. Select that file on the local setup page and authorize Karachi and Lahore individually. Google Workspace policy can prevent access, and testing-mode consent may require reconnecting.

The local service checks connected accounts on startup and every 15 minutes while it is running. It requests read-only Gmail permission and filters university and Classroom messages. It stores short excerpts, source links and possible deadlines in Windows DPAPI-encrypted storage under the current user's LocalAppData CareerOS folder. Private messages are processed locally. Candidate deadlines require confirmation against the original email. The browser displays the latest result every 30 seconds.

Stopping the laptop or local service stops scanning. OAuth credentials remain in the Windows account's encrypted store. The Google setup page and Gmail API routes are loopback-only. This backend must stay private to the laptop. Disconnecting a campus removes its credentials and cached notices from the service. Previously created missions remain in the browser.

## Rebuild

Use Flutter 3.38.1 (Dart 3.10) or a compatible version, plus Node.js 20 or newer.

```sh
flutter pub get
flutter analyze
flutter test
node --test test/gmail.test.mjs
node --test test/offline.test.mjs
flutter build web --release --no-web-resources-cdn --pwa-strategy none
node tool/offline.mjs
node tool/serve.mjs
```

The offline packaging step versions the cache from the compiled files and includes the Flutter renderer. Serve the default contents of build/web at the root of the site. Updates take effect after the previous windows close. Settings reports when the offline shell is available.

The November 10 local audit passed 15 Gmail regression tests, including actual Windows DPAPI encryption, ten Dart tests, and an offline-routing/packaging regression. The rebuilt app was checked in isolated Chrome at phone and desktop viewport sizes, including bilingual setup, OAuth route bypass of the service worker, offline reload, and a synthetic-notice deadline/mission flow. Google responses in scanner tests are fixtures; these checks do not establish real mailbox access or installation on a phone.

## Installation and scope

On Windows, open the preview in Edge or Chrome and use the browser's install-app action if offered. The phone-preview workflow targets **https://salmanflash.github.io/CareerOS/**. After a successful Pages deployment, open that URL in Android Chrome and use Install app / Add to Home screen, or in iPhone Safari use Share → Add to Home Screen. Open the installed app online once and check Settings for offline readiness before disconnecting. Real-device installation and push notifications are still unverified.

The hosted preview uses `--base-href /CareerOS/ --dart-define=CAREEROS_HOSTED=true`. It contains no Node server, OAuth client, tokens or user data, and does not call Gmail endpoints. Gmail automation is available only in the Windows local service. Missions, language and notes are saved separately in each browser/device; there is no automatic transfer between the localhost and hosted previews. The PWA was exercised at a phone viewport with a real offline reload and mission completion, which is not a physical-phone installation test.

Under **Mauqay → Abhi check karo** (Opportunities → Check now), the browser reads published roles from the Greenhouse boards for Careem, Motive, Canonical, Cloudflare and Databricks. Results cover technical internships and co-ops identified by title. Search by role, employer or location, or turn on the Pakistan location filter. Location is a geographic signal only. Verify personal eligibility, deadlines and authorization requirements in the linked employer posting.

Each successful check replaces that board's local snapshot, removing listings that have disappeared. A failed check keeps previous results with their original timestamp. Results older than 24 hours are marked cached, and those older than seven days are hidden. The app limits refreshes to once per minute per session. Missions you already created remain in Progress.

Also included are personal listing intake, two demo listings, a guided GitHub README exercise, bilingual mission tracking, Exam Mode and device-local persistence. Independent Gmail integration is in progress. Cloud sync, scheduled discovery, LinkedIn, hosted AI and push notifications are later milestones. User-entered notes and titles stay in their original language.
