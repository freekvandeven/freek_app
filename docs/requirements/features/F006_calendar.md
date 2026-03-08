# F006 — Calendar

## Summary

A unified calendar view showing tasks, financial transactions, and custom events in monthly/weekly/daily views.

## Priority

Medium

## User Stories

- US-050 through US-055 (see user_stories.md)

## Description

The Calendar provides a unified time-based view across multiple features. It aggregates:
- **Tasks** with due dates (from F002)
- **Financial transactions** on their transaction date (from F004)
- **Custom calendar events** created directly in the calendar

### Views
- **Monthly view**: Shows a month grid with colored dots indicating events on each day. Tapping a day shows a list of that day's events below the grid.
- **Weekly view** (optional, v2): Shows a week timeline with event blocks.
- **Daily view**: List of all events for a selected day, ordered by time.

### Event Sources
| Source | Color | How it appears |
|--------|-------|----------------|
| Tasks (F002) | Blue | Automatically from tasks with due dates |
| Financial transactions (F004) | Green (income) / Red (expense) | Automatically from transactions |
| Custom events (Calendar) | Purple (or user-selected) | Created in the calendar directly |

### Custom Calendar Events
Users can create standalone events not tied to tasks or finances:
- Title (required)
- Description (optional)
- Start date/time (required)
- End date/time (optional)
- All-day toggle
- Color (optional)

### Interaction
- Tapping a task event navigates to the task editor (S006)
- Tapping a financial event navigates to the transaction editor (S012)
- Tapping a custom event shows the event detail (S020) with edit option

## Acceptance Criteria

- [ ] User can see a monthly calendar view
- [ ] Days with events show colored dot indicators
- [ ] User can tap a day to see all events for that day
- [ ] Tasks with due dates appear on the calendar
- [ ] Financial transactions appear on the calendar
- [ ] User can create standalone calendar events
- [ ] Events are color-coded by type
- [ ] Tapping a task event navigates to the task editor
- [ ] Tapping a financial event navigates to the transaction editor
- [ ] Custom events are stored in Firestore and exportable to CSV

## UI / Screens

- S019 — Calendar (monthly view with day detail)
- S020 — Calendar Event Detail (for custom events)

## Data Requirements

- CalendarEvent entity (see data_model.md)
- Reads from Task and FinancialTransaction collections

## Dependencies

- F001 — Authentication
- F002 — Tasks (for task events)
- F004 — Finances (for financial events)

## Open Questions

- Should the calendar be a separate Firestore collection or a virtual view computed client-side?
- Calendar package: `table_calendar`, `syncfusion_flutter_calendar`, or custom?
- Should recurring events be supported natively in the calendar?
- Should there be integration with device calendar (export to Google Calendar, etc.)?
