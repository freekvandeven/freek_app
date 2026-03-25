# Data Model

All data is stored in Cloud Firestore under per-user document paths: `users/{userId}/...`. This ensures strict data isolation between users via Firestore security rules. Access requires the `inviteVerified` custom claim, set during invite-code registration.

---

## Security Collections

### Invite Codes

Stored at: `inviteCodes/{code}`

Client access: **denied** (read/write: false). Only Cloud Functions (Admin SDK) and Firebase console administrators can manage this collection.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| (document ID) | String | Yes | The invite code itself (used as doc ID) |
| createdAt | Timestamp | No | When the code was created |

Invite codes are single-use: deleted by the `createUserWithInvite` Cloud Function after successful user creation.

---

## Entities

### User Profile

Stored at: `users/{userId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Firebase Auth UID |
| email | String | Yes | User email address |
| displayName | String | No | Display name |
| phone | String | No | Phone number |
| bio | String | No | Short biography |
| createdAt | Timestamp | Yes | Account creation time |
| updatedAt | Timestamp | Yes | Last profile update |
| settings | Map | No | User preferences (theme, notifications, etc.) |

#### User Settings (embedded map)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| themeMode | String | No | `light`, `dark`, or `system` |
| notificationsEnabled | bool | No | Whether push notifications are enabled |
| defaultCurrency | String | No | ISO 4217 currency code (default: `EUR`) |
| biometricEnabled | bool | No | Whether biometric lock is active |
| showImagePreviews | bool | No | Show thumbnail images in inventory/recipe lists (default: `true`) |

---

### Task

Stored at: `users/{userId}/tasks/{taskId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique task identifier |
| title | String | Yes | Task title |
| description | String | No | Detailed description |
| isCompleted | bool | Yes | Whether the task is done (default: `false`) |
| dueDate | Timestamp | No | When the task is due |
| completedAt | Timestamp | No | When the task was completed |
| priority | String | No | `low`, `medium`, `high` |
| category | String | No | User-defined category / tag |
| isRepeatable | bool | Yes | Whether the task repeats (default: `false`) |
| repeatType | String | No | `daily`, `weekly`, `monthly`, `yearly` (null if not repeatable) |
| repeatInterval | int | No | Every N days/weeks/months/years (default: `1`) |
| repeatEndDate | Timestamp | No | When the repeating stops (null = forever) |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Recipe

Stored at: `users/{userId}/recipes/{recipeId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique recipe identifier |
| title | String | Yes | Recipe name |
| description | String | No | Short description / summary |
| servings | int | No | Number of servings |
| prepTimeMinutes | int | No | Preparation time in minutes |
| cookTimeMinutes | int | No | Cooking time in minutes |
| ingredients | List\<Map\> | Yes | List of ingredients (see below) |
| instructions | List\<Map\> | Yes | Ordered list of instruction steps (see below) |
| tags | List\<String\> | No | Tags / categories (e.g., `vegetarian`, `dessert`, `quick`) |
| images | List\<String\> | No | List of image URLs |
| primaryImageIndex | int | No | Index of primary image in images list (default: 0) |
| isFavorite | bool | No | Whether marked as favorite (default: `false`) |
| source | String | No | Where the recipe came from (URL, book, etc.) |
| notes | String | No | Personal notes about the recipe |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

#### Ingredient (embedded in Recipe.ingredients)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | String | Yes | Ingredient name |
| quantity | double | No | Amount needed |
| unit | String | No | Unit of measurement (g, ml, cups, pieces, etc.) |

#### RecipeInstruction (embedded in Recipe.instructions)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| text | String | Yes | The instruction step text |
| imageUrl | String | No | Optional image URL for this step |

---

### Financial Transaction

Stored at: `users/{userId}/financialTransactions/{transactionId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique transaction identifier |
| title | String | Yes | Transaction description |
| description | String | No | Additional notes |
| amount | double | Yes | Transaction amount (always positive) |
| type | String | Yes | `income` or `expense` |
| categoryId | String | No | Reference to a FinancialCategory |
| date | Timestamp | Yes | Date of the transaction |
| isRecurring | bool | No | Whether this is a recurring transaction |
| recurringType | String | No | `daily`, `weekly`, `monthly`, `yearly` |
| recurringInterval | int | No | Every N periods |
| recurringEndDate | Timestamp | No | When the recurrence stops |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Financial Category

Stored at: `users/{userId}/financialCategories/{categoryId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique category identifier |
| name | String | Yes | Category name (e.g., "Groceries", "Salary") |
| type | String | Yes | `income` or `expense` |
| icon | String | No | Icon identifier (Material icon name) |
| color | String | No | Hex color code |
| createdAt | Timestamp | Yes | Creation timestamp |

---

### Financial Asset

Stored at: `users/{userId}/financialAssets/{assetId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique asset identifier |
| name | String | Yes | Asset name (e.g., "Savings Account", "Cash") |
| type | String | Yes | `bank_account`, `investment`, `cash`, `crypto`, `other` |
| currentValue | double | Yes | Current value in the asset's currency |
| currency | String | Yes | ISO 4217 currency code |
| description | String | No | Additional notes |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Password Entry (Encrypted)

Stored at: `users/{userId}/passwordEntries/{entryId}`

**Note**: The fields `encryptedPassword` and `encryptedNotes` are encrypted client-side before storage. The encryption key is derived from a master password known only to the user and is never sent to the server.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique entry identifier |
| title | String | Yes | Entry name (e.g., "Gmail", "Netflix") |
| username | String | No | Username / email for the account |
| encryptedPassword | String | Yes | AES-encrypted password (base64 encoded) |
| url | String | No | Website URL |
| encryptedNotes | String | No | AES-encrypted notes (base64 encoded) |
| category | String | No | Category (e.g., "Social", "Finance", "Work") |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Calendar Event

Stored at: `users/{userId}/calendarEvents/{eventId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique event identifier |
| title | String | Yes | Event title |
| description | String | No | Event description |
| startDate | Timestamp | Yes | Event start date/time |
| endDate | Timestamp | No | Event end date/time (null = all-day or point-in-time) |
| isAllDay | bool | No | Whether this is an all-day event |
| type | String | Yes | `custom`, `task`, `financial` |
| linkedEntityId | String | No | ID of the linked Task or Financial Transaction |
| color | String | No | Hex color override |
| imageUrls | List\\<String\\> | No | Firebase Storage download URLs for attached images |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

**Note**: Tasks with due dates and financial transactions automatically appear in the calendar. Users can also create standalone calendar events.

---

### Inventory Place

Stored at: `users/{userId}/inventoryPlaces/{placeId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique place identifier |
| name | String | Yes | Place name (e.g., "Kitchen", "Storeroom") |
| description | String | No | Description of the place |
| locationType | String | No | `home`, `storage`, `other_person`, `other` |
| address | String | No | Physical address or location hint |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Inventory Item

Stored at: `users/{userId}/inventoryItems/{itemId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique item identifier |
| name | String | Yes | Item name |
| description | String | No | Item description |
| placeId | String | Yes | Reference to an InventoryPlace |
| quantity | double | No | Quantity of the item (default: `1`) |
| unit | String | No | Unit (pieces, kg, liters, etc.) |
| category | String | No | Item category (e.g., "Food", "Electronics", "Cleaning") |
| purchaseDate | Timestamp | No | When the item was purchased |
| expiryDate | Timestamp | No | When the item expires |
| reminderDaysBefore | int | No | Days before expiry to send a reminder (default: `3`) |
| barcode | String | No | Barcode / EAN number |
| imageUrl | String | No | Photo of the item |
| price | double | No | Purchase price |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Feedback Entry

Public feedback stored at: `feedback/{feedbackId}` (shared collection, readable/writable by all authenticated users)
Private feedback stored at: `users/{userId}/feedback/{feedbackId}` (per-user collection, only accessible by the owning user)

The app merges both collections into a single list on the feedback screen.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique feedback identifier |
| type | String | Yes | `wish` or `bug` |
| title | String | Yes | Short summary |
| description | String | Yes | Detailed description |
| status | String | Yes | `open`, `acknowledged`, `resolved` (default: `open`) |
| isPrivate | bool | No | Determines storage location: `true` → per-user collection, `false` → shared collection (default: `false`) |
| userId | String | No | Creator's user ID |
| attachedLogs | String | No | App logs attached by the user (captured from in-memory log buffer) |
| imageUrls | List\<String\> | No | Download URLs of images attached via gallery or camera (stored in Firebase Storage) |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Knowledge Page

Stored at: `users/{userId}/knowledgePages/{pageId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique page identifier |
| title | String | Yes | Page title |
| content | String | Yes | Page content in Markdown format |
| parentPageId | String | No | Parent page ID for hierarchy (null = root page) |
| tags | List\<String\> | No | Tags for searching/filtering |
| sortOrder | int | No | Order among siblings (for manual sorting) |
| createdAt | Timestamp | Yes | Creation timestamp |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

### Conversation Topic

Stored at: `users/{userId}/conversations/{topicId}` (private per-user collection)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique topic identifier |
| title | String | Yes | Short conversation topic summary |
| description | String | Yes | Detailed description of what to discuss |
| personOrGroup | String | Yes | Name of the person or group this topic is for |
| priority | String | Yes | `low`, `medium`, `high` (default: `medium`) |
| status | String | Yes | `open`, `resolved` (default: `open`) |
| imageUrls | List\<String\> | No | Download URLs of attached images (stored in Firebase Storage) |
| createdAt | Timestamp | Yes | Creation timestamp |
| resolvedAt | Timestamp | No | When the topic was marked as resolved |
| updatedAt | Timestamp | Yes | Last update timestamp |

---

## Relationships

```
User (users/{userId})
 ├── 1:N ──▶ Task
 ├── 1:N ──▶ Recipe
 ├── 1:N ──▶ FinancialTransaction ──▶ references FinancialCategory
 ├── 1:N ──▶ FinancialCategory
 ├── 1:N ──▶ FinancialAsset
 ├── 1:N ──▶ PasswordEntry (encrypted)
 ├── 1:N ──▶ CalendarEvent ──▶ optionally links to Task or FinancialTransaction
 ├── 1:N ──▶ InventoryPlace
 │            └── 1:N ──▶ InventoryItem (via placeId)
 ├── 1:N ──▶ FeedbackEntry
 ├── 1:N ──▶ KnowledgePage ──▶ self-referencing hierarchy (parentPageId)
 └── 1:N ──▶ ConversationTopic
```

## Data Flow

```
┌─────────────┐     HTTPS / gRPC      ┌──────────────────┐
│  Flutter App │ ◄──────────────────► │  Cloud Firestore  │
│  (client)    │                       │  (per-user data)  │
└──────┬──────┘                       └──────────────────┘
       │                                       ▲
       │  .env config                          │
       │  (injected at build)                  │ Firestore triggers
       │                                       │
       ▼                                       ▼
┌─────────────┐                       ┌──────────────────┐
│ Firebase Auth│                       │ Cloud Functions   │
│ (login/auth) │                       │ (export, cleanup) │
└─────────────┘                       └──────────────────┘
```

- **Client → Firestore**: Direct reads/writes using Firestore SDK with offline persistence
- **Client → Firebase Auth**: Authentication flows (login, signup, logout)
- **Cloud Functions**: CSV export, data cleanup, scheduled reminder processing
- **Encryption**: Password Vault data is encrypted/decrypted on the client only

## CSV Export

All collections support CSV export. Cloud Functions provide endpoints to:
1. Query all documents in a user's collection
2. Flatten nested fields
3. Return a downloadable `.csv` file

Alternatively, in-app export can generate CSV files locally and share them.

## Open Questions

- Whether to store recipe images in Firebase Storage or as external URLs
- Exact encryption algorithm and key derivation function for Password Vault
- Whether Calendar Events should be a virtual view (computed from tasks + transactions) or a separate collection
- Pagination strategy for large collections
