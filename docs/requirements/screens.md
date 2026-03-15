# Screens & Navigation

## Screen Inventory

| ID | Screen Name | Description | Feature | Auth Guard |
|----|------------|-------------|---------|------------|
| S001 | Splash | Native + Flutter splash during app init | — | No |
| S002 | Login | Firebase authentication (email/password) | F001 | No |
| S003 | Biometric Lock | Device auth / biometric prompt | F001 | No |
| S004 | Home / Dashboard | Main landing with quick overview of all modules | — | Yes |
| S005 | Task List | List of all tasks with filters/sort | F002 | Yes |
| S006 | Task Detail/Edit | Create or edit a single task | F002 | Yes |
| S007 | Recipe List | Browse and search all recipes | F003 | Yes |
| S008 | Recipe Detail | View a single recipe | F003 | Yes |
| S009 | Recipe Edit | Create or edit a recipe | F003 | Yes |
| S010 | Finance Overview | Dashboard with income/expense summary and assets | F004 | Yes |
| S011 | Transaction List | List of all financial transactions | F004 | Yes |
| S012 | Transaction Edit | Create or edit a transaction | F004 | Yes |
| S013 | Asset List | List of financial assets | F004 | Yes |
| S014 | Asset Edit | Create or edit a financial asset | F004 | Yes |
| S015 | Category Management | Manage financial categories | F004 | Yes |
| S016 | Password Vault | List of password entries | F005 | Yes + Biometric |
| S017 | Password Entry Detail | View a decrypted password entry | F005 | Yes + Biometric |
| S018 | Password Entry Edit | Create or edit a password entry | F005 | Yes + Biometric |
| S019 | Calendar | Monthly/weekly/daily calendar view | F006 | Yes |
| S020 | Calendar Event Detail | View/edit a calendar event | F006 | Yes |
| S021 | Inventory Places | List of inventory places | F007 | Yes |
| S022 | Inventory Place Detail | View items in a specific place | F007 | Yes |
| S023 | Inventory Place Edit | Create or edit a place | F007 | Yes |
| S024 | Inventory Item List | Full item list with expiry sorting/filtering | F007 | Yes |
| S025 | Inventory Item Edit | Create or edit an inventory item | F007 | Yes |
| S026 | Feedback List | List of wishes and bug reports | F008 | Yes |
| S027 | Feedback Edit | Create or edit a feedback entry | F008 | Yes |
| S028 | Knowledge Bank | Tree/list view of knowledge pages | F009 | Yes |
| S029 | Knowledge Page View | Read-only view of a knowledge page (rendered Markdown) | F009 | Yes |
| S030 | Knowledge Page Edit | Create or edit a knowledge page (Markdown editor) | F009 | Yes |
| S031 | Settings | User settings, theme, export, logout | F010 | Yes |
| S032 | Data Export | Select collections and export to CSV | F010 | Yes |
| S033 | Profile | Edit user profile (name, phone, bio) | F010 | Yes |
| S034 | Connections | Quick links to external apps and integration management | F011 | Yes |
| S035 | Gemini Chat | AI-powered chat assistant using Google Gemini | F012 | Yes |
| S036 | Conversation List | List of conversation topics with filters by person/status and sorting by priority/date | F013 | Yes |
| S037 | Conversation Edit | Create or edit a conversation topic with priority, person/group, images | F013 | Yes |

## Navigation Structure

The app uses a primary navigation pattern with a **bottom navigation bar** (mobile) or **side navigation rail** (web/desktop) for the main sections, and standard push navigation for detail/edit screens.

### Primary Navigation Tabs

| Tab | Icon | Destination | Description |

### Quick Actions (Global)

Long-pressing any AppBar title across the entire app brings up a Quick Actions bottom sheet with shortcuts to: Report a Bug, Request a Feature, New Task, New Recipe, and New Knowledge Entry. This is implemented via the shared `QuickActionsTitle` widget wrapping every AppBar title.
|-----|------|-------------|-------------|
| Home | `home` | S004 | Dashboard overview |
| Tasks | `check_circle` | S005 | Task management |
| Calendar | `calendar_today` | S019 | Calendar view |
| More | `menu` | Drawer/Menu | Access to all other sections |

### "More" Menu / Drawer

| Item | Destination |
|------|-------------|
| Recipes | S007 |
| Finances | S010 |
| Password Vault | S016 |
| Inventory | S021 |
| Knowledge Bank | S028 |
| Feedback | S026 |
| Conversations | S036 |
| Connections | S034 |
| Gemini AI | S035 |
| Settings | S031 |

## Navigation Map

```
App Launch
  └── S001 Splash Screen
        └── Auth Check
              ├── Not logged in ──▶ S002 Login
              │                      └── Success ──▶ S003 Biometric Lock
              └── Logged in ──▶ S003 Biometric Lock
                                  └── Authenticated ──▶ S004 Home/Dashboard

S004 Home/Dashboard
  ├── [Tab: Tasks] ──▶ S005 Task List
  │                      ├── + ──▶ S006 Task Edit (create)
  │                      └── Tap task ──▶ S006 Task Edit (edit)
  │
  ├── [Tab: Calendar] ──▶ S019 Calendar
  │                        └── Tap event ──▶ S020 Calendar Event Detail
  │                                           └── Edit ──▶ linked entity or S020 edit
  │
  ├── [More: Recipes] ──▶ S007 Recipe List
  │                        ├── Tap recipe ──▶ S008 Recipe Detail
  │                        │                    └── Edit ──▶ S009 Recipe Edit
  │                        └── + ──▶ S009 Recipe Edit (create)
  │
  ├── [More: Finances] ──▶ S010 Finance Overview
  │                         ├── Transactions ──▶ S011 Transaction List
  │                         │                     ├── + ──▶ S012 Transaction Edit
  │                         │                     └── Tap ──▶ S012 Transaction Edit
  │                         ├── Assets ──▶ S013 Asset List
  │                         │               ├── + ──▶ S014 Asset Edit
  │                         │               └── Tap ──▶ S014 Asset Edit
  │                         └── Categories ──▶ S015 Category Management
  │
  ├── [More: Password Vault] ──▶ Biometric Prompt ──▶ S016 Password Vault
  │                                                     ├── Tap ──▶ S017 Entry Detail
  │                                                     │             └── Edit ──▶ S018 Entry Edit
  │                                                     └── + ──▶ S018 Entry Edit (create)
  │
  ├── [More: Inventory] ──▶ S021 Inventory Places
  │                          ├── Tap place ──▶ S022 Place Detail (items at place)
  │                          │                  └── Tap item ──▶ S025 Item Edit
  │                          ├── + ──▶ S023 Place Edit (create)
  │                          ├── Edit place ──▶ S023 Place Edit
  │                          └── All Items ──▶ S024 Inventory Item List
  │                                             ├── + ──▶ S025 Item Edit (create)
  │                                             └── Tap ──▶ S025 Item Edit
  │
  ├── [More: Knowledge Bank] ──▶ S028 Knowledge Bank (tree view)
  │                               ├── Tap page ──▶ S029 Page View
  │                               │                 └── Edit ──▶ S030 Page Edit
  │                               └── + ──▶ S030 Page Edit (create)
  │
  ├── [More: Feedback] ──▶ S026 Feedback List
  │                         ├── + ──▶ S027 Feedback Edit (create)
  │                         ├── Tap ──▶ S027 Feedback Edit
  │                         └── Copy button ──▶ copies entry to clipboard
  │
  ├── [More: Conversations] ──▶ S036 Conversation List
  │                               ├── + ──▶ S037 Conversation Edit (create)
  │                               ├── Tap ──▶ S037 Conversation Edit
  │                               └── Filter / Sort buttons
  │
  └── [More: Settings] ──▶ S031 Settings
                             ├── Theme toggle
                             ├── Export Data ──▶ S032 Data Export
                             └── Logout ──▶ S002 Login
```

---

## Screen Details

### S001 — Splash Screen

**Purpose**: Show branding while the app initializes Firebase and checks auth state.

**Key Elements**:
- App logo centered
- Loading indicator
- App name below logo

**Navigation**:
- From: OS app launch
- To: S002 (Login) if not authenticated, S003 (Biometric Lock) if authenticated

---

### S002 — Login

**Purpose**: Firebase authentication screen.

**Key Elements**:
- Email/password fields with autofill support (password manager integration)
- Sign in button
- Sign up option
- "Forgot password" link
- Possible social login buttons (future)

**Navigation**:
- From: S001 (Splash) or S031 (Settings → Logout)
- To: S003 (Biometric Lock) on success

---

### S003 — Biometric Lock

**Purpose**: Require device authentication (biometrics or PIN) before granting app access.

**Key Elements**:
- Biometric prompt (fingerprint, face, PIN fallback)
- Retry button if authentication fails
- Logout option

**Navigation**:
- From: S002 (Login) or S001 (Splash, if already logged in)
- To: S004 (Home) on success

---

### S004 — Home / Dashboard

**Purpose**: Overview of the user's personal data across all modules.

**Key Elements**:
- Summary cards: upcoming tasks, today's calendar events, expiring inventory items, financial summary
- Quick action buttons (add task, add transaction, etc.)
- Navigation to all sections

**Navigation**:
- From: S003 (Biometric Lock)
- To: All sections via tabs and more menu

---

### S005 — Task List

**Purpose**: View and manage all tasks.

**Key Elements**:
- List/grid of tasks with title, due date, priority indicator, completion toggle
- Filter by: completed/pending, priority, category
- Sort by: due date, priority, creation date
- FAB to add new task
- Swipe-to-complete or swipe-to-delete

**Navigation**:
- From: S004 (Tab)
- To: S006 (Task Detail/Edit)

---

### S010 — Finance Overview

**Purpose**: Dashboard showing financial health at a glance.

**Key Elements**:
- Total income vs. expenses (current month)
- Net balance
- Pie chart of expenses by category
- List of financial assets with total value
- Quick links to transactions, assets, categories

---

### S016 — Password Vault

**Purpose**: Secure list of all password entries. **Requires biometric re-authentication** to access.

**Key Elements**:
- Master password prompt (first time / session) to derive decryption key
- List of entries with title, username, category
- Search/filter
- FAB to add new entry
- Each entry shows a "copy password" button (decrypts and copies)

---

### S019 — Calendar

**Purpose**: Visual calendar showing tasks, financial events, and custom events.

**Key Elements**:
- Monthly view with day cells showing dot indicators
- Weekly/daily detail view
- Color-coded by event type (task, financial, custom)
- Tap a day to see events
- FAB to add a custom event

---

### S021 — Inventory Places

**Purpose**: Manage inventory locations.

**Key Elements**:
- List/grid of places with name, type, item count
- FAB to add new place
- Tap to see items at that place
- Button to view all items across all places
- Items sorted by expiry date (soonest first)

---

### S028 — Knowledge Bank

**Purpose**: Browse and manage knowledge pages in a tree hierarchy.

**Key Elements**:
- Tree view or nested list of pages
- Search bar to find pages by title or tag
- FAB to create new root page
- Tap page to view (S029)

---

### S029 — Knowledge Page View

**Purpose**: Read-only rendered view of a knowledge page.

**Key Elements**:
- Rendered Markdown content
- Title header
- Tags displayed
- Edit button → S030
- Create child page button
- Breadcrumb navigation showing page hierarchy

---

### S031 — Settings

**Purpose**: App configuration and account management.

**Key Elements**:
- Theme toggle (light/dark/system)
- Default currency selection
- Notification preferences
- Export data (→ S032)
- About / app version
- Logout button

---

## Open Questions

- Whether to use a bottom navigation bar with 4-5 tabs or a drawer-based navigation
- Exact dashboard cards/widgets on the Home screen
- Whether recipe images should be full-width hero images or thumbnails
- Pagination or infinite scroll for long lists
