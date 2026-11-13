# Local milestone cost audit

| Component used | Operation | Billing required | Data and limits |
| --- | --- | --- | --- |
| Flutter SDK and Dart | Local compilation and UI | No | Uses installed tools and free packages. |
| Node.js | Local preview and offline packaging | No | Preview server binds to 127.0.0.1. |
| Browser storage and service worker | Missions, preferences and offline shell | No | Saved in the current profile. Storage availability and retention depend on browser settings. |
| GitHub / LinkedIn guidance | Local outlines, draft editing and manual clipboard copy | No | No API, sign-in, model, posting service or credentials. Drafts remain in browser storage and encrypted backups; copying is user-triggered. Offline guides remain available. |
| Greenhouse Job Board API | User-triggered public GET requests for five employer boards | No | No API key, account, application submission or private mission data. Requests time out after 12 seconds and failed boards retain their last successful timestamp. |
| Local Gmail scanner | Read-only Gmail requests with the owner's Desktop app OAuth client | No billing is provisioned | Requires user setup and university permission. Runs every 15 minutes while the local service is on. Real account authorization remains unverified. |
| Windows DPAPI | Encrypt local OAuth credentials and short mail excerpts | No | Bound to the current Windows account. Ciphertext is stored outside the repository and excluded from Git. |
| GitHub Pages and standard public Actions runner | Build and serve the static phone preview | No | Public repository, standard Ubuntu runner, no paid services. Only compiled frontend assets are uploaded, retained for one day. Local Gmail service and data are excluded. |

The public listing endpoints and authentication rules are documented in the [Greenhouse Job Board API](https://docs.greenhouse.io/job-board). Live availability depends on each employer keeping its board public.

GitHub documents [Pages availability for public repositories on GitHub Free](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages) and [free standard runners in public repositories](https://docs.github.com/en/billing/concepts/product-billing/github-actions). The workflow is limited to this public repository and does not select larger runners or enable billing.

The local build uses deterministic guidance and local email parsing. No paid model, analytics integration or paid fallback is configured. Independent Gmail requires the owner's OAuth configuration. Verify permissions and quota behavior against the actual account before treating the connection as ready.
