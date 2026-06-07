# API Service — Node.js + Express + PostgreSQL

Primary backend REST API for LKS 2026.  
Handles all CRUD operations for the User resource and publishes events to SQS.

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Health check — returns `{"status":"ok"}` |
| GET | `/api/users` | List all users |
| GET | `/api/users/:id` | Get a single user by ID |
| POST | `/api/users` | Create a new user |
| PUT | `/api/users/:id` | Update an existing user |
| DELETE | `/api/users/:id` | Delete a user |

## Request / Response format

**POST / PUT body:**
```json
{
  "name":        "Budi Santoso",
  "email":       "budi@example.com",
  "institution": "SMK Negeri 1 Purwokerto",
  "position":    "Student",
  "phone":       "08123456789"
}
```

**Successful create response (201):**
```json
{
  "id":          1,
  "name":        "Budi Santoso",
  "email":       "budi@example.com",
  "institution": "SMK Negeri 1 Purwokerto",
  "position":    "Student",
  "phone":       "08123456789",
  "created_at":  "2026-01-01T00:00:00.000Z"
}
```

## Local development

```bash
cd api
cp .env.example .env        # Fill in DB credentials
npm install
npm run dev                 # nodemon — auto-restarts on file changes
```

Or with Docker Compose from the project root:
```bash
docker compose up -d api
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | 8080 | HTTP port |
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | lksdb | Database name |
| `DB_USER` | lksadmin | Database user |
| `DB_PASSWORD` | — | Database password (use SSM in production) |
| `AWS_REGION` | us-east-1 | Region for SQS client |
| `SQS_QUEUE_URL` | — | SQS queue URL (optional — events silently skipped if not set) |
| `CORS_ORIGIN` | * | Allowed CORS origin (set to ALB DNS in production) |

## Database

On first startup the API automatically creates the `users` table if it does not exist.
No migration tool is required for this project.

```sql
CREATE TABLE users (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(255) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  institution VARCHAR(255),
  position    VARCHAR(255),
  phone       VARCHAR(50),
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);
```

## SQS events

Every successful create / update / delete publishes a message to SQS:

```json
{
  "eventType": "user.created",
  "payload":   { "userId": 1, "email": "budi@example.com" },
  "timestamp": "2026-01-01T00:00:00.000Z",
  "source":    "lks-api"
}
```

If `SQS_QUEUE_URL` is not set the publish is silently skipped — useful in local dev.
