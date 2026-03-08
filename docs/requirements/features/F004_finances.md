# F004 — Finances

## Summary

Financial tracking with income/expense transactions, categories, recurring transactions, asset management, and summary visualizations.

## Priority

High

## User Stories

- US-030 through US-037 (see user_stories.md)

## Description

Users can track their personal finances by logging income and expense transactions, categorizing them, managing financial assets, and viewing summaries.

### Transactions
- **Create a transaction**: title, amount, type (income/expense), category, date, optional description
- **Recurring transactions**: mark a transaction as recurring (daily, weekly, monthly, yearly) with interval and end date
- **Edit / delete** transactions
- **List view**: all transactions with filters by type, category, date range, and sort by date or amount

### Categories
- User-defined categories for income and expense
- Each category has: name, type (income/expense), icon, color
- Default categories created on first use (e.g., Groceries, Salary, Rent, Entertainment)
- CRUD operations on categories

### Financial Assets
- Track holdings: bank accounts, investments, cash, crypto, other
- Each asset: name, type, current value, currency, description
- CRUD operations
- Total net worth calculated from all assets

### Finance Overview Dashboard (S010)
- **Period selector**: current month, previous month, custom range
- **Summary**: total income, total expenses, net balance for the period
- **Pie chart**: expenses by category
- **Asset summary**: total value across all assets
- **Quick links**: to transactions, assets, categories

### Calendar Integration
Financial transactions appear on the calendar (F006) on their transaction date.

## Acceptance Criteria

- [ ] User can create income and expense transactions
- [ ] User can assign a category to a transaction
- [ ] User can view a summary of income vs. expenses for a period
- [ ] User can create, edit, and delete financial categories
- [ ] User can create, edit, and delete financial assets
- [ ] User can see total net worth across assets
- [ ] User can mark transactions as recurring
- [ ] User can see an expense breakdown by category (pie chart)
- [ ] User can filter and sort transactions
- [ ] Financial transactions appear on the calendar
- [ ] Default categories are created on first use
- [ ] All financial data is exportable to CSV

## UI / Screens

- S010 — Finance Overview
- S011 — Transaction List
- S012 — Transaction Edit
- S013 — Asset List
- S014 — Asset Edit
- S015 — Category Management

## Data Requirements

- FinancialTransaction entity
- FinancialCategory entity
- FinancialAsset entity
(see data_model.md)

## Dependencies

- F001 — Authentication
- F006 — Calendar (transactions shown in calendar)

## Open Questions

- Should there be budget tracking (set monthly budget per category)?
- Should recurring transactions auto-generate future instances or be computed on the fly?
- Should there be multi-currency support with conversion rates?
- Chart library: `fl_chart`, `charts_flutter`, or `syncfusion_flutter_charts`?
