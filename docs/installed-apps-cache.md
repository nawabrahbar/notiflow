# Shared Installed-Apps List & Uninstalled Apps — Feature Specification

**Status:** Implemented in v1.6.1 (`lib/data/services/installed_apps_cache.dart`)
**Platform:** Android (iOS cannot list other installed apps — see `ios-platform-limitations.md`)
**Last discussed:** 18 Nov 2026

This document records every decision taken while designing the shared installed-apps list, on-demand icon loading and the "uninstalled app" state, so nothing is forgotten when implementation starts. **Decided** items were agreed with the product owner. **Proposed** items are implementation suggestions that may still change. **Open** items still need an answer.

---

## 1. Problem

Opening the Activity tab for the first time takes a long time before anything appears.

Investigation (18 Nov 2026) found the local database is **not** the cause: `notiflow.db` was only 72 KB and its queries take milliseconds. The delay comes from loading every installed app with its icon:

- `ActivityScreen._loadNativeEvents()` waits for `getInstalledApplications()` before showing any entry. It only needs app names and icons.
- Native `AndroidNotificationBridge.loadInstalledApplications()` walks every launcher app (163 on the test phone), loads each label and icon, draws the icon into a bitmap, compresses it to PNG and sends all of them over the platform channel. Estimated 1–3 seconds.

Things that make it worse:

1. The list is cached only inside the Activity screen. Add Apps loads the same list again; there is no app-wide cache.
2. The Activity screen throws its copy away on every app resume and reloads everything. On first launch the notification-permission dialog can cause a second full reload.
3. Native loads run on one single-thread executor, so a second load waits behind the first.
4. Activity log, digest and app list are loaded one after another instead of together.
5. Minor: `getActivityLog` / `getDigest` run on the Android main thread, and the digest runs one query per window. Fast at current data sizes.

---

## 2. One shared, app-wide installed-apps list

**Decided**

- There is one shared list of installed apps for the whole app instead of a separate load per screen.
- Loading starts when the user lands on the dashboard, **in the background** after the dashboard has appeared. The dashboard never waits for it.
- The list is **not** thrown away and reloaded on every resume.

**Decided — split names from icons**

- The shared list first holds only lightweight data: package name, app name, system-app flag. This is fast for all apps.
- Icons are the slow part. They are fetched **on demand, per app**, and kept in memory once loaded, so the same icon is never fetched twice in a session.

**Decided — refreshing the list**

- On resume, ask Android only for apps that were installed, updated or removed since the last check, and update just those entries. No full reload.

**Proposed**

- Native side: a lightweight "list apps" call (no icons) plus an "icons for these packages" call that takes a list of package names.
- Use `PackageManager.getChangedPackages(sequenceNumber)` (Android 8+) to detect changes on resume; fall back to a light full list without icons if it is unavailable.
- Run independent loads (activity log, digest, app list) in parallel.
- The Activity log and digest could be read off the Android main thread.

---

## 3. Using the shared list on each screen

### Activity log — **Decided**

- The log shows **immediately** from the database, with no waiting for the app list.
- Only the icons of apps that appear in the log are requested (usually 10–20), and they fill in as they arrive.
- Until an icon arrives, the existing placeholder icon is shown. If the app has a rule, the icon saved with that rule is used as a fallback.

### Add Apps — **Decided**

- The list of names appears instantly from the shared list.
- Icons load in batches as the user scrolls, sized from the **actual screen** so one rule works for phone and tablet:
  - **First load:** about two screens' worth of apps (phone ≈ 16–20 apps; tablet 2-column grid ≈ 30–40 apps).
  - **Next batch:** when the user scrolls about halfway through what is already loaded, fetch the next screen or two ahead.
  - Fast flings skip fetching icons for rows that flew past.
  - Icons already loaded are kept, so scrolling back does not fetch them again.
- When the user searches or changes the category chip, icons for the visible matching apps are fetched first.
- The same rule adapts automatically to phone, the tablet 2-column grid (see `docs/design-reference/tablet/*/apps.png`), rotation and split-screen.

### Rules page and Schedule Rule Editor — **Decided**

- No change needed for loading: these already use the icon and name saved with each managed app when it was added, and do not load the installed-apps list.
- They use the shared list only to know whether an app is still installed (see section 4).

---

## 4. Uninstalled apps that still have rules

**Decided**

If the user added a rule for an app and later uninstalls that app:

- **Rules page:** the app card is shown **grey**, an **"Uninstalled"** badge replaces the Allowed / Muted status badge, and the toggle is disabled. Tapping the card still works so the user can delete the rule.
- **Activity log:** old entries for that app are shown greyed out with an "Uninstalled" label. The icon falls back to the one saved with the rule.
- **Reinstall:** the rules start working again automatically with no setup.
- This is **separate from "dormant" apps** (`ManagedApp.isDormantVault`): dormant apps came from a backup and were never installed, and they stay hidden on the Rules page. Uninstalled apps stay visible but greyed.

**Decided — accuracy safeguards**

- Whether an app is installed is checked by asking Android about that package directly, not by checking the launcher app list. Some apps have no launcher icon (hidden or work-profile apps) and would otherwise wrongly look uninstalled.
- Nothing is greyed until the shared list has finished loading, so cards do not flicker on startup.

**Proposed**

- "Uninstalled" is a runtime state derived from the shared list, not saved in the rules data, so a reinstall needs no migration.

---

## 5. Dropped ideas

- **A–Z fast-scroll strip on Add Apps** (like the launcher app drawer): discussed and **dropped** on 18 Nov 2026; not needed.

---

## 6. Resolved questions

- **Search bar position on tablet.** Decided: tablet matches phone — search bar at the bottom with the frosted blur, edge fade and the hint "Search".

---

## 7. Known limitations

- The manifest's `<queries>` only covers launcher apps. Without `QUERY_ALL_PACKAGES`, a package that isn't visible to Notiflow looks "not installed" to `getPackageInfo`. Managed apps come from the launcher list, so they are normally visible; a managed app whose launcher entry was removed may show as uninstalled.
- `getChangedPackages` needs Android 8.0 (API 26). On older versions, a resume doesn't refresh the list; it refreshes on the next app start.
- The Catch-Up Digest cards don't grey out uninstalled apps; only the Activity event cards and Rules cards do.
