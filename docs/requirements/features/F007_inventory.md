# F007 — Inventory Management

## Summary

An inventory management system to track items across multiple physical locations, with expiry date tracking, reminders, and categorization.

## Priority

Medium

## User Stories

- US-060 through US-069 (see user_stories.md)

## Description

Users can define physical places where they store items (kitchen, storeroom, someone else's house, etc.) and then track individual items at those places. The system emphasizes expiry date tracking to help the user consume perishable items before they expire.

### Inventory Places
- Define locations where items are stored
- Each place has: name, description, type (home, storage, other person, other), optional address
- CRUD operations on places
- View all items at a specific place

### Inventory Items
- Each item belongs to exactly one place
- Fields: name, description, quantity, unit, category, purchase date, expiry date, reminder days before expiry, barcode, image, price
- CRUD operations on items
- Move items between places (update `placeId`)

### Expiry Tracking
- Items with expiry dates are highlighted and sortable
- **Default sort**: expiry date ascending (soonest first)
- **Color coding**:
  - Red: expired
  - Orange: expiring within reminder window
  - Green: not expiring soon
- **Reminders**: Configurable per item — notify N days before expiry. Default: 3 days.
- Reminder delivery: in-app notification or push notification (via Firebase Cloud Messaging)

### Global Item View
- View all items across all places in one list
- Filter by place, category, expiry status
- Sort by expiry date, name, purchase date

### Barcode Scanning (Low Priority)
- Optional: scan a barcode to auto-fill item name (requires barcode database API)
- At minimum: store barcode value for future reference

## Acceptance Criteria

- [ ] User can create, edit, and delete inventory places
- [ ] User can create, edit, and delete inventory items within a place
- [ ] User can set purchase date and expiry date on items
- [ ] Items are sortable by expiry date (soonest first)
- [ ] Expired items are visually highlighted (red)
- [ ] Items expiring within the reminder window are highlighted (orange)
- [ ] User receives reminders N days before item expiry
- [ ] User can move items between places
- [ ] User can view all items across all places
- [ ] User can filter items by place, category, and expiry status
- [ ] Inventory data is exportable to CSV

## UI / Screens

- S021 — Inventory Places (list of places)
- S022 — Inventory Place Detail (items at a place)
- S023 — Inventory Place Edit (create/edit place)
- S024 — Inventory Item List (all items, global view)
- S025 — Inventory Item Edit (create/edit item)

## Data Requirements

- InventoryPlace entity
- InventoryItem entity
(see data_model.md)

## Dependencies

- F001 — Authentication

## Open Questions

- Should there be barcode scanning in v1 or deferred?
- Push notification implementation for expiry reminders (Cloud Functions scheduled job?)
- Should items have a photo upload feature?
- Should there be a "shopping list" derived from consumed/expired items?
- Should inventory items link to recipes (e.g., ingredients in stock)?
