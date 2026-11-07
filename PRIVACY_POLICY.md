# Privacy Policy for Notiflow

**Effective Date:** November 7, 2026  
**Last Updated:** November 7, 2026  
**Application Name:** Notiflow (`com.notificationhandler.notification_handler`)  
**Developer:** Mohammad Enayatullah (`nawabrahbar`)

---

## 1. Overview & Privacy-First Commitment

**Notiflow** is an offline, local-only Android notification scheduling and focus management utility.

We believe your notifications and device usage are strictly private:
- **Zero Data Collection:** Notiflow does **not** collect, transmit, rent, sell, or share any personal data, notification contents, or installed application lists with the developer or any third party.
- **100% On-Device Processing:** All notification filtering, schedule evaluation, muted-notification activity logging, and `.notiflow` rule backups happen exclusively on your Android device.
- **No Internet Transmission:** Notiflow operates without any backend servers, cloud databases, analytics SDKs, crash-reporting trackers, or advertising networks.

---

## 2. Permissions We Request & Why

To function as an automatic notification scheduler and blocker on Android, Notiflow requests the following device permissions:

### A. Notification Listener Access (`android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`)
- **Why it is required:** Android requires Notification Listener access so Notiflow can detect when a managed application posts a notification during an active mute schedule or focus override, suppress/cancel that notification during your scheduled block window, and record the muted notification in your on-device **Activity** tab so you can review what you missed later.
- **How your data is handled:**
  - Notification metadata (app package name, title, message text, and timestamp) is evaluated **in memory on your device** against your local schedules.
  - Muted notification logs are stored locally inside the app's private Android storage (`SharedPreferences`) and are capped automatically.
  - Notification data **never leaves your device**.

### B. Installed Applications List (`android.permission.QUERY_ALL_PACKAGES`)
- **Why it is required:** Allows Notiflow to display your installed launcher applications (name, package identifier, and icon) so you can choose which apps to manage or mute on a schedule.
- **How your data is handled:** Your installed app list is read locally on your device to render the app picker UI and is never uploaded or shared anywhere.

### C. Boot Completed (`android.permission.RECEIVE_BOOT_COMPLETED`)
- **Why it is required:** Ensures your active notification schedules and background listener resume automatically after you restart your phone.

### D. Storage Access Framework (Export & Import `.notiflow` Backup Files)
- **Why it is required:** When you explicitly tap **Export .notiflow File** or **Select .notiflow File**, Android's system file picker (`ACTION_CREATE_DOCUMENT` / `ACTION_OPEN_DOCUMENT`) is used to save or load your rules backup file in the folder you select. Notiflow cannot access any other files on your device.

---

## 3. Data Storage, Retention & Deletion

All app data (managed app selections, schedule rules, temporary overrides, and the muted notification activity log) is stored locally in your device's private application sandbox.

You have full control over your data at all times:
1. **Clear Muted Activity Log:** Tap the **Trash / Clear** icon in the **Activity** tab to permanently erase all recorded notification history on your device.
2. **Reset All Rules:** Go to **Settings → Reset All Rules** to wipe all schedules, managed apps, and temporary overrides.
3. **Revoke Notification Access:** Go to **Settings → Open Android Settings** (or Android System Settings → Special app access → Notification access) to disable Notiflow at any time.
4. **Uninstall the App:** Uninstalling Notiflow immediately and permanently deletes all locally stored preferences, schedules, and activity logs from your device.

---

## 4. Third-Party Services & Children's Privacy

- **Third-Party Sharing:** Notiflow does not integrate with any third-party analytics, advertising, cloud storage, or tracking services. No data is shared with third parties.
- **Children's Privacy:** Notiflow does not knowingly collect any personal information from anyone, including children under the age of 13.

---

## 5. Changes to This Privacy Policy

If we update this Privacy Policy in future versions of Notiflow, we will update the "Last Updated" date at the top of this page and publish the updated policy in the official repository.

---

## 6. Contact Us

If you have any questions or concerns regarding this Privacy Policy or Notiflow's privacy practices, please contact us via GitHub Issues:
- **GitHub Repository:** [https://github.com/nawabrahbar/notiflow](https://github.com/nawabrahbar/notiflow)
- **Issues & Support:** [https://github.com/nawabrahbar/notiflow/issues](https://github.com/nawabrahbar/notiflow/issues)
