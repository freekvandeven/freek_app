# F008 — Feedback

## Summary

An in-app feedback system where users can submit wishes (feature requests) and bug reports, with the ability to copy them to clipboard for use in external tools.

## Priority

Medium

## User Stories

- US-070 through US-074 (see user_stories.md)

## Description

The feedback system provides a simple way for the user to capture ideas and bugs while using the app. All entries are stored in Firestore and can be reviewed, edited, and exported.

### Feedback Entry
- **Type**: wish (feature request) or bug (issue report)
- **Title**: short summary (required)
- **Description**: detailed explanation (required)
- **Status**: open → acknowledged → resolved

### Feedback List
- List of all feedback entries
- Filter by type (wish / bug) and status
- Sort by creation date
- Each entry has a "copy to clipboard" button

### Copy to Clipboard
When the user taps the copy button, the feedback entry is formatted as structured text and copied to the device clipboard. Example format:

```
**[Bug] Title here**

Description of the issue...

Status: Open
Created: 2026-03-08
```

This makes it easy to paste into AI coding assistants, GitHub issues, or other tools.

### Editing / Status Tracking
- User can edit title and description
- User can change status (e.g., mark as resolved after fixing)
- User can delete entries

## Acceptance Criteria

- [ ] User can create a feedback entry (wish or bug)
- [ ] User can view all feedback entries
- [ ] User can filter by type and status
- [ ] User can copy a formatted feedback entry to clipboard
- [ ] User can edit a feedback entry
- [ ] User can delete a feedback entry
- [ ] User can change the status of a feedback entry
- [ ] Feedback entries are stored in Firestore
- [ ] Feedback entries are exportable to CSV

## UI / Screens

- S026 — Feedback List
- S027 — Feedback Edit

## Data Requirements

- FeedbackEntry entity (see data_model.md)

## Dependencies

- F001 — Authentication

## Open Questions

- Should feedback support file attachments (screenshots)?
- Should there be a way to auto-create GitHub issues from feedback?
- Should feedback entries include device/app version info automatically?
