# F002 — Tasks / To-Do List

## Summary

A full task management system with CRUD operations, due dates, priorities, categories, and repeatable tasks.

## Priority

High

## User Stories

- US-010 through US-018 (see user_stories.md)

## Description

Users can create, read, update, and delete tasks. Each task has a title and optional description, due date, priority level, and category. Tasks can be marked as repeatable so they auto-regenerate on a schedule.

### Task Creation
- Title (required)
- Description (optional, multi-line text)
- Due date (optional, date picker)
- Priority: Low / Medium / High (default: Medium)
- Category (optional, free-text or from previously used categories)
- Repeatable toggle with options: daily, weekly, monthly, yearly
  - Repeat interval (every N days/weeks/months/years)
  - Repeat end date (optional)

### Task List View
- Shows all tasks grouped or filterable by:
  - Status: Pending / Completed
  - Priority
  - Category
  - Due date range
- Sort options: Due date (soonest first), Priority (highest first), Created date
- Quick complete: toggle checkbox inline
- Swipe actions: complete, delete

### Repeatable Tasks
When a repeatable task is marked as completed:
1. The current instance is marked as completed with `completedAt` timestamp
2. A new task instance is automatically created with the next due date based on the repeat schedule
3. This continues until the `repeatEndDate` is reached (if set)

### Calendar Integration
Tasks with due dates appear in the Calendar (F006) automatically.

## Acceptance Criteria

- [ ] User can create a task with title
- [ ] User can set due date, priority, category, and description
- [ ] User can view all tasks in a list
- [ ] User can filter tasks by status, priority, and category
- [ ] User can sort tasks by due date and priority
- [ ] User can mark a task as completed
- [ ] User can edit a task
- [ ] User can delete a task
- [ ] Repeatable tasks generate a new instance when completed
- [ ] Tasks with due dates appear in the Calendar
- [ ] Tasks are synced to Firestore in real-time
- [ ] Tasks are exportable to CSV

## UI / Screens

- S005 — Task List
- S006 — Task Detail/Edit

## Data Requirements

- Task entity (see data_model.md)

## Dependencies

- F001 — Authentication (user must be logged in)
- F006 — Calendar (tasks shown in calendar)

## Open Questions

- Should completed tasks be hidden by default or shown with strikethrough?
- Should there be a "today" / "upcoming" / "overdue" quick filter?
- Should subtasks be supported?
