# Push Notifications Implementation Plan

Server-side push notifications for Sweep using Gmail Push API, Google Cloud, and APNs.

## Architecture

```
Gmail → Cloud Pub/Sub → Cloud Function → APNs → iPhone
                              ↓
                          Firestore
                              ↑
            iOS App → HTTP Cloud Functions
```

## Components

### 1. Google Cloud Infrastructure

**Pub/Sub Topic**: `gmail-notifications`
- Receives push notifications from Gmail API
- Triggers Cloud Function on message

**Firestore Collections**:
```
users/{email}
  - deviceToken: string
  - refreshToken: string (OAuth)
  - watchExpiry: timestamp
  - pendingEmails: [{ sender, subject, timestamp }]
```

**Cloud Functions**:
| Function | Trigger | Purpose |
|----------|---------|---------|
| `onGmailNotification` | Pub/Sub | Process Gmail push, send APNs |
| `registerDevice` | HTTP POST | Store device token + OAuth token |
| `appOpened` | HTTP POST | Reset pending emails + renew watch |

### 2. Notification Flow

1. Gmail receives new email
2. Gmail publishes to Pub/Sub topic
3. `onGmailNotification` triggers:
   - Fetch email metadata via Gmail API (using stored refresh token)
   - Add to `pendingEmails` array in Firestore
   - Format notification based on pending count
   - Send APNs with `collapse-id: "sweep-inbox"`

### 3. Notification Format

**1-3 emails** (one per line):
```
Alice: Meeting tomorrow
Bob: Quick question
Carol: Invoice attached
```

**4+ emails** (single line):
```
5 new emails from Alice (2), Bob (2), Carol
```

Senders ordered by most recent. Duplicates show count.

### 4. Watch Renewal

Gmail watches expire after 7 days.

- **On app open**: `appOpened` endpoint renews watch
- **Before expiry**: If watch expires in <24 hours, send friendly push:
  "Open Sweep to keep notifications active"
- **Scheduled check**: Daily Cloud Function checks for expiring watches

### 5. iOS App Changes

**New responsibilities**:
- Request notification permission
- Register device token with server on launch/refresh
- Call `appOpened` endpoint when app becomes active
- Handle notification tap (open app)

**New files**:
- `NotificationService.swift` - APNs registration, permission handling
- `PushAPIClient.swift` - HTTP calls to Cloud Functions

## Infrastructure Setup (CLI Scripts)

All infrastructure managed via `gcloud` CLI for reproducibility.

| Script | Purpose |
|--------|---------|
| `scripts/setup-gcloud.sh` | Create project, enable APIs, create Pub/Sub topic, create Firestore |
| `scripts/deploy-functions.sh` | Deploy all three Cloud Functions |
| `scripts/setup-secrets.sh` | Store APNs key + API secret in Secret Manager |

## Server Code Structure

```
server/
├── functions/
│   ├── package.json
│   ├── index.js           # Entry points
│   ├── gmail.js           # Gmail API helpers
│   ├── apns.js            # APNs sending
│   ├── notifications.js   # Format logic
│   └── firestore.js       # DB helpers
└── scripts/
    ├── setup-gcloud.sh
    ├── deploy-functions.sh
    └── setup-apns.sh
```

## Security Considerations

- HTTP endpoints require shared secret header (`X-Sweep-Key`)
- HTTP endpoints validate email exists in Firestore (registered via OAuth)
- OAuth refresh tokens encrypted at rest in Firestore
- APNs key stored in Secret Manager, not in code
- Shared secret stored in Secret Manager
- No PII logged in Cloud Functions

### Authentication Flow

1. User completes Gmail OAuth in app → app has user's email
2. App calls `registerDevice` with email, device token, refresh token, and `X-Sweep-Key` header
3. Server validates secret header + stores user in Firestore
4. Subsequent `appOpened` calls validated against: secret header + email exists in Firestore

## Cost Estimate (post-free-tier)

| Users | Emails/day | Monthly Cost |
|-------|------------|--------------|
| 1,000 | 50,000 | ~$2-5 |
| 10,000 | 500,000 | ~$15-20 |
| 100,000 | 5,000,000 | ~$150-200 |

## Implementation Order

1. [ ] GCloud project setup (`setup-gcloud.sh`)
2. [ ] Firestore schema + security rules
3. [ ] Cloud Function: `registerDevice`
4. [ ] Cloud Function: `appOpened` with watch renewal
5. [ ] Cloud Function: `onGmailNotification`
6. [ ] APNs setup + integration
7. [ ] iOS: Notification permission + token registration
8. [ ] iOS: `appOpened` endpoint call
9. [ ] Testing: End-to-end flow
10. [ ] Daily watch expiry check function
