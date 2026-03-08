# F009 — Knowledge Bank

## Summary

A personal wiki / knowledge base system where users can create, edit, and browse pages of information written in Markdown, organized in a hierarchical structure.

## Priority

Medium

## User Stories

- US-080 through US-086 (see user_stories.md)

## Description

The Knowledge Bank is a personal wiki where the user can create pages to store any kind of textual information. Pages are written in Markdown and rendered in a clean reading view.

### Pages
- **Title** (required)
- **Content** in Markdown format (required)
- **Tags** for categorization and search (optional)
- **Parent page** for hierarchical organization (optional — null = root page)
- **Sort order** for manual ordering among siblings

### Hierarchy
Pages can be nested: a page can have a parent, forming a tree structure. The Knowledge Bank main view shows this tree, allowing users to browse through nested pages.

Example structure:
```
📄 Cooking Tips
   📄 Knife Skills
   📄 Seasoning Guide
📄 Travel
   📄 Packing Checklist
   📄 Japan 2026
      📄 Tokyo Itinerary
      📄 Kyoto Itinerary
📄 Programming Notes
   📄 Flutter Tips
   📄 Firebase Tricks
```

### View Mode
- Rendered Markdown with proper headings, lists, code blocks, links, images, bold/italic, etc.
- Breadcrumb navigation showing the page's position in the hierarchy
- Links to child pages
- Edit button

### Edit Mode
- Markdown text editor (plain text input with preview toggle or split view)
- Title input
- Tag input (chips)
- Parent page selector (dropdown or tree picker)
- Save / cancel

### Search
- Search by title (substring match)
- Search by tags
- Results link directly to the page

## Acceptance Criteria

- [ ] User can create a knowledge page with title and Markdown content
- [ ] User can edit a knowledge page
- [ ] User can delete a knowledge page
- [ ] User can view a page in rendered Markdown format
- [ ] User can organize pages in a tree hierarchy (parent/child)
- [ ] User can tag pages
- [ ] User can search pages by title or tag
- [ ] Knowledge Bank main view shows page tree
- [ ] Breadcrumb navigation shows page position in hierarchy
- [ ] Deleting a parent page handles child pages gracefully (reparent to root or cascade delete — TBD)
- [ ] Pages are stored in Firestore
- [ ] Pages are exportable to CSV

## UI / Screens

- S028 — Knowledge Bank (tree/list view)
- S029 — Knowledge Page View (rendered Markdown)
- S030 — Knowledge Page Edit (Markdown editor)

## Data Requirements

- KnowledgePage entity with self-referencing `parentPageId` (see data_model.md)

## Dependencies

- F001 — Authentication

## Packages

- `flutter_markdown` or `markdown_widget` for rendering Markdown

## Open Questions

- Should there be a WYSIWYG editor or plain Markdown with preview?
- Should pages support embedded images (uploaded to Firebase Storage)?
- What happens when a parent page is deleted? (reparent children to root, cascade delete, or prevent deletion?)
- Should there be page linking (wiki-style `[[Page Name]]` links)?
- Should the Knowledge Bank support encryption for sensitive pages?
