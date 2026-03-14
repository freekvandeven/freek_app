# F003 — Recipes

## Summary

A recipe management system where users can store, browse, and manage their personal recipe collection.

## Priority

Medium

## User Stories

- US-020 through US-029 (see user_stories.md)

## Description

Users can maintain a personal digital cookbook. Each recipe has structured data (ingredients, instructions, timing) and can be tagged, favorited, and searched.

### Recipe Creation / Editing
- Title (required)
- Description / summary (optional)
- Ingredients list:
  - Each ingredient has: name (required), quantity (optional), unit (optional)
  - Dynamic list — add/remove ingredients
- Instructions:
  - Ordered list of steps (each step is a text string)
  - Dynamic list — add/remove/reorder steps
- Servings (optional, number)
- Prep time in minutes (optional)
- Cook time in minutes (optional)
- Tags (optional, multi-select chips from common tags + custom)
- Image (optional, upload or URL)
- Source (optional, URL or text reference)
- Notes (optional, personal annotations)
- Video links (optional, list of URLs — YouTube, Vimeo, TikTok, Instagram, etc.)
- Favorite toggle

### Recipe List View
- Card-based or list view of all recipes
- Search by title
- Filter by tags
- Filter by favorites
- Sort by: name, creation date, cook time

### Recipe Detail View
- Clean, readable layout for following while cooking
- Large title, image (if present)
- Ingredients displayed clearly with quantities
- Instructions shown as numbered steps
- Metadata: servings, prep time, cook time
- Tags shown as chips
- Video links section: YouTube embedded player, other platforms as tappable cards
- Edit and delete buttons

## Acceptance Criteria

- [ ] User can create a recipe with title, ingredients, and instructions
- [ ] User can edit a recipe
- [ ] User can delete a recipe
- [ ] User can view a recipe in a clean reading format
- [ ] User can mark a recipe as favorite
- [ ] User can tag recipes
- [ ] User can search recipes by name
- [ ] User can filter recipes by tags and favorites
- [ ] Ingredients and instructions are dynamic lists (add/remove)
- [ ] Recipes are synced to Firestore
- [ ] Recipes are exportable to CSV
- [ ] User can add video links (YouTube, Vimeo, etc.) to a recipe
- [ ] YouTube videos are embedded inline in recipe detail view
- [ ] Non-YouTube video links open in external browser

## UI / Screens

- S007 — Recipe List
- S008 — Recipe Detail
- S009 — Recipe Edit

## Data Requirements

- Recipe entity with embedded Ingredient list (see data_model.md)

## Dependencies

- F001 — Authentication

## Open Questions

- Should recipe images be stored in Firebase Storage or as external URLs?
- Should there be a "shopping list" feature derived from recipe ingredients?
- Should there be a meal planner that links recipes to calendar days?
- Import recipes from URL (web scraping)?
