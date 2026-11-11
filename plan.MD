# Notiflow v1.6.0 Redesign & Multi-Schedule Plan
**Design Systems**: Botanical Sanctuary (Light) & Botanical Nocturne (Dark)  
**Target Release**: v1.6.0  

---

## 1. Design Reference Assets & Directory Structure
- [x] Evaluated all 42 reference files in `/design-reference` (HTML prototypes, PNG mockups, `dark_colors.md`, `ligh_colors.md`).
- [ ] Relocate `/design-reference` to `docs/design-reference/` to maintain a clean project root while preserving all mockups and HTML references.

---

## 2. Design System & Theme Engine Updates (`lib/presentation/theme/app_theme.dart`)
- **Typography** (via `google_fonts`):
  - Primary Display Serif: `Newsreader` (Headlines, Splash quotes, Screen titles).
  - Primary Interface Sans: `Plus Jakarta Sans` (Body, labels, buttons, chips).
- **Dark Theme Tokens (`Botanical Nocturne`)**:
  - `canvas`: `#0F1312` / `#101412`
  - `surfaceContainer`: `#1A211D` / `#1C201E`
  - `surfaceContainerHigh`: `#222B25` / `#272B29`
  - `outline`: `#2A362F`
  - `primary`: `#DDA15E` (Terracotta) / `#FCBC76`
  - `secondary`: `#A7D4A3` (Sage) / `#BECCA3`
  - `onSurface`: `#F3F4F1` / `#E0E3E0`
  - `onSurfaceVariant`: `#9AA79B` / `#D5C3B4`
- **Light Theme Tokens (`Botanical Sanctuary`)**:
  - `canvas`: `#FEF8F6`
  - `surfaceContainer`: `#F8F2F0` / `#FFFFFF`
  - `outline`: `#D4C4B7` / `#E7E1DF`
  - `primary`: `#7D562D` / `#D4A373`
  - `secondary`: `#5A6242` / `#DEE7BF`
  - `onSurface`: `#1D1B1A`
  - `onSurfaceVariant`: `#50453B` / `#82756A`
- **Component Themes**:
  - Bottom Navigation Bar with Botanical icons (`Rules`, `Apps`, `Activity`, `Settings`).
  - Elevated and Outlined buttons with rounded corners (`12px` - `16px`).
  - Botanical rounded switches with terracotta active track and dark pip.

---

## 3. Data & Model Layer Updates
### A. Multi-Schedule Support
- In `lib/data/repositories/schedule_repository.dart`:
  - Add `List<ScheduleRule> getRulesForApp(String appId)` (preserving `getRuleForApp` for single-rule backward compatibility).
  - Update `deleteAppsAndRules` and `toggleAppMonitoring` to seamlessly handle multiple schedules per app.
  - Multi-rule evaluation in `ScheduleEvaluator` is already tested and supports compound schedule evaluation.

### B. Reusable Saved Rule Templates (Feature 2)
- Create `lib/domain/models/rule_template.dart`:
  - Fields: `id`, `name`, `mode`, `startTime`, `endTime`, `daysOfWeek`, `allowVipContacts`.
- In `ScheduleRepository`:
  - `List<RuleTemplate> get savedTemplates`
  - `Future<void> saveRuleTemplate(RuleTemplate template)`
  - Persist templates to `SharedPreferences` (`pref_saved_rule_templates`).
  - Initialize with 3 pre-seeded templates:
    1. *Work Focus Hours* (`09:00 - 17:00`, Weekdays, Block)
    2. *Deep Night Silence* (`22:00 - 07:00`, Everyday, Block)
    3. *Weekend Peace* (`00:00 - 23:59`, Weekends, Block)
  - When any rule is saved in the editor, automatically add or update it in the template registry.

---

## 4. Screen-by-Screen UI Redesign

### 1. Splash Screen (`splash_screen.dart`)
- Implement the Botanical emblem with rotating outer dashed orbit ring and subtle glow aura.
- Literary typography: *"Notiflow"* with italic subtitle *"Silence the noise. Protect what matters."*
- Slim progress line with ambient glow.

### 2. Onboarding Journey (`onboarding_screen.dart`)
- **Step 1 (`p_screen_1.html`)**:
  - Top progress pill: `STEP 1 OF 3`.
  - Headline: *"Take back control of your attention"*.
  - 3 Feature cards with squircle icons and colored category badges (`RULES`, `OFFLINE`, `BYPASS`).
  - Full-width terracotta *"Get Started"* CTA button.
- **Step 2 (`p_screen_2.html`)**:
  - Top progress pill: `STEP 2 OF 3 · PERMISSION HEALTH`.
  - Headline: *"Notification Access is required"*.
  - Clean 3-step numbered card (Open Android Settings → Find Notiflow → Switch Toggle ON).
  - Primary button: *"Open Android Settings"* + secondary *"Continue to Rule Setup"*.
  - No sideload/restricted settings warnings.
- **Step 3 (`p_screen_3.html`)**:
  - Top progress pill: `STEP 3 OF 3`.
  - Headline: *"Import Rules"*.
  - Elevated central card: *"Import .notiflow Backup File"* with cloud upload icon and radial blur aura.
  - Anchored bottom CTA button: *"Done"*.

### 3. Home / Dashboard Screen (`dashboard_screen.dart`)
- **Header**: `Notiflow` with Newsreader serif branding + theme toggle pill (`Dark` / `Light`).
- **Ambient Greeting Card**: Dynamic greeting (*"Good morning/evening"*), inspirational focus quote, and *"Mindful Silence Active · Until X:XX AM"*.
- **Metrics Row**: Side-by-side cards for *Intercepted* (muted items count) and *Permitted* (passed items count).
- **Quick Session Overrides**: 3-pill grid (*Mute 15m*, *Mute 1h*, *Priority Only*).
- **Managed Apps List**: Clean app cards with category icon, active schedule summary line, and botanical switch.

### 4. App Details Screen (`app_details_screen.dart`)
- **App Identity Card**: Large app icon, app name, category chip, and Master Switch.
- **Real-Time Triage Status Card**: Live status pill (`ALLOWED` / `SILENCED`), active override tag, and reason description.
- **Quick Overrides Grid**: 4-pill grid (*15m Mute*, *30m Mute*, *1h Mute*, *Today 24h Quiet*).
- **Active Schedule Rules Section (Feature 1)**:
  - Header: `Active Schedule Rules (N)`.
  - List of all schedule cards for the app with individual switches, time ranges, overnight badges, and delete actions.
  - Dashed button: `+ Add New Schedule`.
- **Bottom Actions**: *"Remove from Rules Page"* and *"Done"*.

### 5. Schedule Rule Editor (`schedule_rule_editor.dart`)
- **Quick Load Template / Saved Rule Dropdown (Feature 2)**:
  - Dropdown at the top with bookmark icon.
  - Selecting an item immediately populates Rule Name, Block/Allow mode, Time window, and Days of week.
- **Rule Name Input**: Clean field with edit icon.
- **Interception Behavior**: Side-by-side cards for *BLOCK* (Silence alerts) vs *ALLOW* (Pass through) with checkmark indicators.
- **Time Window**: Card pair with Start and End time selectors, arrow divider, and overnight interval calculator.
- **Recurrence Days**: Day presets (*Everyday*, *Weekdays*, *Weekends*) + 7-day pill toggles (M, T, W, T, F, S, S).
- **Urgent Calls Escalation**: Toggle card for priority repeated emergency pings.
- **Save Schedule Rule Button**: Terracotta button that saves the rule and updates saved templates.

### 6. Add Apps Screen (`add_apps_screen.dart`)
- **Search Bar**: Input with search icon and clear button.
- **Category Filter Chips**: *All Apps*, *Messaging*, *Social*, *Productivity*, *System*.
- **App List**: Clean rows showing icon, title, category, and action button (`+ Add` or `Manage`).
- **Empty State**: Botanical *"No peaceful matches"* card.

### 7. Activity Log Screen (`activity_screen.dart`)
- **Header & Metric Summary**: 3 metrics cards (*Total Alerts*, *Silenced*, *Allowed*).
- **Filter Pills**: *All*, *Silenced*, *Allowed*.
- **Event Audit Cards**: Time, app icon, sender/title, preview text, and state chip.
- **Clear Log Dialog**: Clean confirmation modal with toast feedback.

### 8. Settings Screen (`settings_screen.dart`)
- **Theme Switcher**: Botanical Dark / Light mode switch.
- **Engine & Background Services**: Notification access status and battery optimization guide.
- **Triage & Automation Preferences**: *Keep Unmanaged Apps Untouched* and *Allow Priority Phone Calls*.
- **On-Device Integrity & Storage**: Summary cards for *Encrypted Local Storage* and *Zero Telemetry*.
- **Rules Backup & Portability**: Export and Import `.notiflow` file buttons.
- **Danger Zone**: *Reset All Rules* confirmation dialog.

---

## 5. Verification & Testing
- Run all unit and widget tests (`flutter test`).
- Add tests for:
  - Multi-schedule querying and deletion per app.
  - Rule template persistence, loading, and auto-filling in Schedule Editor.
- Verify light and dark mode rendering across all 8 screens.
