# F010 — Settings & Data Export

## Summary

Application settings (theme, preferences, account management) and the ability to export all user data to CSV files.

## Priority

Medium

## User Stories

- US-090 through US-093 (see user_stories.md)

## Description

### Settings Screen
Centralized settings for the app:

| Setting | Description | Options |
|---------|-------------|---------|
| Theme | Visual theme | Light / Dark / System |
| Default currency | Currency for financial data | ISO 4217 codes (EUR, USD, GBP, etc.) |
| Notifications | Enable/disable push notifications | On / Off |
| Biometric lock | Enable/disable biometric on app open | On / Off |
| App version | Display current version | Read-only |
| Logout | Sign out of the app | Action button |

### Data Export
Users can export their data to CSV files for backup or migration purposes.

#### Export Flow
1. User navigates to Settings → Export Data (S032)
2. User selects which collections to export (checkboxes):
   - Tasks
   - Recipes
   - Financial Transactions
   - Financial Categories
   - Financial Assets
   - Password Entries (decrypted — requires master password)
   - Calendar Events
   - Inventory Places
   - Inventory Items
   - Feedback Entries
   - Knowledge Pages
3. User taps "Export"
4. App generates CSV files (one per collection)
5. Files are bundled into a ZIP or shared individually
6. User saves/shares via the system share sheet

#### CSV Format
- UTF-8 encoding with BOM
- Comma-separated
- First row: headers matching field names
- Nested objects (e.g., recipe ingredients) are serialized as JSON strings in the CSV cell
- Timestamps formatted as ISO 8601

#### Implementation Options
1. **Client-side**: Generate CSV files directly in the app using the `csv` package
2. **Cloud Functions**: Call a Cloud Function that queries Firestore and returns CSV data
3. **Hybrid**: Client-side for small datasets, Cloud Functions for large exports

### Logout
- Clears Firebase Auth session
- Clears any cached encryption keys
- Navigates to Login screen (S002)

## Acceptance Criteria

- [ ] User can toggle between light, dark, and system theme
- [ ] Theme preference is persisted
- [ ] User can set a default currency
- [ ] User can export selected collections to CSV
- [ ] CSV files use proper formatting (headers, UTF-8, ISO 8601 dates)
- [ ] Password entries require master password to export decrypted
- [ ] User can share/save exported files
- [ ] User can log out
- [ ] Logout clears auth session and cached keys

## UI / Screens

- S031 — Settings
- S032 — Data Export

## Data Requirements

- User Profile settings (see data_model.md)
- Access to all collections for export

## Dependencies

- F001 — Authentication (logout)
- F005 — Password Vault (encrypted export requires master password)
- All other features (for data export)

## Open Questions

- Should export be client-side or server-side (Cloud Functions)?
- Should there be a data import feature (CSV → Firestore)?
- Should password entries be exportable at all, or only non-encrypted data?
- Should there be automatic scheduled backups?
