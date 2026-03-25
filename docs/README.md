# Personal App — Documentation

This folder contains all requirements, design decisions, and specifications for the **Personal App**.

## Structure

```
docs/
├── README.md                                    # This file
├── requirements/
│   ├── overview.md                              # App vision, goals, platforms, constraints
│   ├── user_stories.md                          # User stories grouped by feature
│   ├── data_model.md                            # All entities, fields, relationships, data flow
│   ├── screens.md                               # 32 screens, navigation map, screen details
│   ├── non_functional.md                        # Security, performance, platforms, theming, testing
│   ├── tech_decisions.md                        # Firebase, CI/CD, packages, config approach
│   └── features/
│       ├── feature_template.md                  # Template for new feature specs
│       ├── F001_authentication.md               # Auth, biometric lock, per-screen guard
│       ├── F002_tasks.md                        # Task / to-do list with repeating tasks
│       ├── F003_recipes.md                      # Recipe management
│       ├── F004_finances.md                     # Transactions, categories, assets, charts
│       ├── F005_password_vault.md               # E2E encrypted password manager
│       ├── F006_calendar.md                     # Unified calendar (tasks + finances + events)
│       ├── F007_inventory.md                    # Places, items, expiry tracking, reminders
│       ├── F008_feedback.md                     # Wishes & bugs with clipboard copy
│       ├── F009_knowledge_bank.md               # Personal wiki with Markdown pages
│       └── F010_settings_export.md              # Settings, theming, CSV data export
└── decisions/
    ├── ADR_template.md                          # Template for new ADRs
    ├── ADR_001_security_model.md                # Hybrid encryption, multi-layer auth, secrets
    ├── ADR_002_cicd_pipeline.md                 # GitHub Actions, conventional commits, tag deploys
    ├── ADR_003_forkability.md                   # Config-driven branding, .env approach
    └── ADR_004_release_process.md               # Release workflow, version scheme, dev builds
```

## How to Use

1. Start with [requirements/overview.md](requirements/overview.md) for the big picture.
2. Review features in [requirements/features/](requirements/features/) — each feature has its own spec.
3. Check user stories in [user_stories.md](requirements/user_stories.md) for all scenarios.
4. Review the data model in [data_model.md](requirements/data_model.md) for all entities and fields.
5. See all screens and navigation in [screens.md](requirements/screens.md).
6. Non-functional requirements (security, platforms, theming) in [non_functional.md](requirements/non_functional.md).
7. Technology choices in [tech_decisions.md](requirements/tech_decisions.md).
8. Architecture decisions in [decisions/](decisions/).

## Feature Summary

| ID | Feature | Priority | Status |
|----|---------|----------|--------|
| F001 | Authentication & Biometric Lock | High | Specified |
| F002 | Tasks / To-Do List | High | Specified |
| F003 | Recipes | Medium | Specified |
| F004 | Finances | High | Specified |
| F005 | Password Vault (E2E Encrypted) | High | Specified |
| F006 | Calendar | Medium | Specified |
| F007 | Inventory Management | Medium | Specified |
| F008 | Feedback (Wishes & Bugs) | Medium | Specified |
| F009 | Knowledge Bank | Medium | Specified |
| F010 | Settings & Data Export | Medium | Specified |

## Key Decisions

| ADR | Decision | Status |
|-----|----------|--------|
| ADR-001 | Hybrid security model (E2E for passwords, Firestore rules for rest) | Accepted |
| ADR-002 | GitHub Actions CI/CD with tag-based deployment | Accepted |
| ADR-003 | Config-driven forkability (`.env` + config files) | Accepted |
| ADR-004 | Plain Flutter (no Flood) | Accepted |

## Status

| Document | Status |
|----------|--------|
| Overview | ✅ Complete |
| Features (10 specs) | ✅ Complete |
| User Stories | ✅ Complete |
| Data Model | ✅ Complete |
| Screens & Navigation | ✅ Complete |
| Non-Functional Reqs | ✅ Complete |
| Tech Decisions | ✅ Complete |
| ADRs (3) | ✅ Complete |

## Generated Documentation

Auto-generated API documentation can be produced with:

```bash
./scripts/generate-docs.sh
```

| Output | Generator | Command |
|--------|-----------|---------|
| `docs/generated/dart/` | `dart doc` | `dart doc --output docs/generated/dart` |
| `functions/docs/` | `typedoc` | `cd functions && npm run docs` |
| `functions/openapi.yaml` | Hand-maintained | OpenAPI 3.0 spec for Cloud Functions |

Generated output is git-ignored. Run the script locally to browse the HTML docs.
