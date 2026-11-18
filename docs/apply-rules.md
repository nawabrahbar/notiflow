# Apply Rules — Bulk-Apply Saved Rules to Many Apps

Apply one or more **saved rules** to many apps in one go, instead of opening each app and adding schedules one by one.

## Entry point

* **Rules tab → floating "Apply rules" button** (`rules-apply-fab`), bottom-right on phone and tablet, with the floating **Add app** button (`rules-add-app-fab`) stacked above it once at least one app is managed.
  * Shown only on the Rules tab, and hidden while multi-select (long-press delete) is active.
  * Both buttons shrink to icons while you scroll down the list and expand again when you scroll up. They never scroll away with the list.
  * The Rules list has extra bottom space so the button never cover the last app card.

## Wizard (`BulkApplyScreen`, `lib/presentation/screens/bulk_apply_screen.dart`)

Title **Apply Rules**. The system Back button and the back arrow close the wizard without changing anything.

### Phone (< 600dp): 3 steps

A step indicator at the top reads **1. Rules → 2. Apps → 3. Review**. The bottom bar has **Back** and **Next**, and on the last step **Apply**.

1. **Choose rules**: *"Pick saved rules or create a new one."* Every saved rule (including the default *Focus Hours*) is shown with a summary such as *"Block · 9:00 AM - 5:00 PM · Mon-Fri"* or *"Allow all day · Everyday"*. Tap a rule to select it; you can select several.
   * **New rule** (first tile, `bulk-new-rule`): opens the Schedule Rule Editor as **New Rule** (empty name, *Save Rule* button). Saving adds it to Settings → Saved Rules and returns to the wizard with the new rule already selected. If the same behaviour, times and days are already saved, a dialog offers **Use <rule>** to select that rule instead, since saved rules can't share the same schedule.
2. **Choose apps**: shows Notiflow apps first, then other installed apps.
   * Search field, category chips (*All apps, Messaging, Social, Productivity, Other, System*), and **Select all / Clear**, which act on the filtered list.
   * Each app shows its status: *"Managed · N rules"*, *"Managed · no rules"* or *"Not managed yet"*.
3. **Review**: a headline *"N rules → M apps"* and a line *"X new schedules · Y already applied"* (the second part only when something is skipped).
   * Notes, when relevant: *"Apps that already have a rule are skipped for it."* and *"N apps will be added to Notiflow."*
   * **RULES** and **APPS** sections list the selection; apps that will be added get a **NEW** badge.
   * **Apply** is disabled and reads **Already applied** when nothing new would be created.

**Next** stays disabled until at least one rule (step 1) or one app (step 2) is selected.

### Tablet (≥ 600dp): side by side

* The rules panel (left, narrower, with the same **New rule** tile) and the apps panel (right) are shown side by side, with no steps.
* A review bar at the bottom shows the live summary (*"N rules → M apps"* over *"X new schedules · Y already applied"*) and the **Apply** button.
* Until a rule and an app are picked, the bar reads *"Choose rules and apps"* with *"Pick at least one rule and one app to continue."*

## Rules of applying

* **Duplicates are skipped**: if an app already has a schedule with the same mode, times and days (`templateAlreadyApplied`), that rule is not added again for that app. This also applies to duplicates within the same batch.
* **Overlapping times are allowed**: different rules that overlap are all added; the engine already handles overlapping schedules.
* **Apps not yet in Notiflow** are added automatically. A matching app waiting in the Dormant Vault is restored instead of being added twice.
* Each new schedule takes the saved rule's name, mode, times, days and VIP setting, and is turned on.
* Everything is saved in one go and synced to the native engine once.

## Result sheet with flexible undo (`BulkApplyResultSheet`, `lib/presentation/widgets/bulk_apply_result_sheet.dart`)

After **Apply**, the wizard closes and a **Rules applied** bottom sheet opens on the Rules tab.

* Summary line: *"N new schedules · M apps · K already applied"* (the last part only when something was skipped), with the hint *"Tap × to remove a rule from one app, or undo a whole app. Only schedules added just now are removed."*
* One row per app: icon, name, and a subtitle (*"Added to Notiflow · N new · K already applied"*).
  * A chip for each new rule with a **×** that removes **just that rule from that app**.
  * A **×** on the app row that **undoes everything this batch did to that app**.
  * *"Already had: …"* lists the rules that were skipped for that app.
* **Undo all** removes every schedule this batch created. **Done** closes the sheet and keeps everything.
* Every undo asks first (*"Remove <rule>?"*, *"Undo for <app>?"*, *"Undo everything?"*), then shows a toast: *"Removed <rule> from <app>"*, *"Undid changes to <app>"* or *"Undid N schedules"*.
* Undo never touches schedules the apps already had. An app is removed from Notiflow only if this batch added it and none of its rules are left. Apps you already managed always stay.
* The sheet updates live. If you change something elsewhere, removed items disappear, and when nothing from the batch is left it says *"Nothing from this batch is left."*
* After the sheet is closed, everything can still be edited the normal way from each app's details page.

## Code map

| Piece | Location |
|---|---|
| Models (`BulkApplyTarget`, `BulkApplyAppResult`, `BulkApplyResult`) and duplicate check `templateAlreadyApplied` | `lib/domain/models/bulk_apply.dart` |
| `previewBulkApply`, `applyTemplatesToApps`, `removeBulkAppliedRules` | `lib/data/repositories/schedule_repository.dart` |
| Wizard UI and `savedRuleSummary` | `lib/presentation/screens/bulk_apply_screen.dart` |
| Result sheet and undo | `lib/presentation/widgets/bulk_apply_result_sheet.dart` |
| Floating button | `lib/presentation/screens/dashboard_screen.dart` (`_buildApplyRulesFab`, `_openBulkApply`) |

## Possible follow-ups (not built)

* An **Apply rules** icon in the Rules multi-select bar (pre-selects the chosen apps).
* An **Apply to apps…** action on each saved rule in Settings → Saved Rules (opens the wizard with that rule pre-selected).
