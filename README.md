# AnyNote

[![Go Version](https://img.shields.io/badge/Go-1.22%2B-00ADD8?logo=go)](https://go.dev/)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.41%2B-02569B?logo=flutter)](https://flutter.dev/)
[![Tests](https://img.shields.io/badge/tests-1276%2B-brightgreen)]()
[![License](https://img.shields.io/badge/license-Proprietary-red)]()

**Local-first, privacy-first note-taking with end-to-end encryption.**

AnyNote ensures your notes are never readable by anyone but you. All encryption and decryption happens on your device -- the server only ever sees opaque encrypted blobs. Even if the server is compromised, your data stays private.

---

## How It Works

1. **Key derivation** -- Your master password is strengthened with Argon2id, producing a root encryption key.
2. **Per-item keys** -- Each note gets a unique 32-byte key derived from the root key via BLAKE2b (`BLAKE2b(rootKey, noteUUID)`). Compromising one note's key reveals nothing about others.
3. **Encryption** -- Note content is encrypted client-side with XChaCha20-Poly1305, an AEAD cipher that provides both confidentiality and integrity.
4. **Sync** -- Only the encrypted blob leaves your device. The server stores and replicates it without ever having the ability to decrypt.
5. **Decryption** -- Upon pulling from another device, the client re-derives the per-item key and decrypts locally.

The server is architecturally **zero-knowledge**: it has no access to plaintext content, encryption keys, or user passwords.

---

## Key Features

- **End-to-end encrypted** -- Client-side encryption with XChaCha20-Poly1305; server stores only encrypted blobs
- **Offline-first** -- Full read/write capability without network; automatic sync on reconnect
- **Client-driven sync** -- Version vectors with last-writer-wins (LWW) conflict resolution
- **AI composition** -- LLM proxy with streaming SSE; use your own API key or the shared server LLM
- **Platform publishing** -- One-click publish to WeChat and Xiaohongshu via headless Chrome
- **Full-text search** -- FTS5 with CJK tokenization and Unicode support
- **Secure sharing** -- Time-limited note sharing with expiry and view limits
- **Real-time collaboration** -- CRDT-based (RGA) concurrent editing over WebSocket
- **Version history** -- Full note revision history with one-click restore
- **Multi-platform** -- iOS, Android, macOS, Windows, Linux, and Web

---

## Architecture

```
+-------------------+       +-----------------------+
|   Flutter Client  |       |      Go Server        |
|                   |       |                       |
| XChaCha20-Poly1305|<----->|  Encrypted blob store |
| Argon2id / BLAKE2b|  HTTPS|  (PostgreSQL)         |
| Drift (SQLCipher) |       |  Redis (job queue)    |
| Riverpod + go_rou|       |  MinIO (objects)      |
|       tr          |       |  chromedp (publish)   |
+-------------------+       +-----------------------+
```

**Thin server, thick client.** The server is a storage and relay layer. All business logic, encryption, and conflict resolution live on the client.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Go 1.22+, chi router, PostgreSQL 16, Redis (asynq), chromedp |
| Frontend | Flutter 3.41+, Drift (SQLite + SQLCipher), Riverpod, go_router |
| Encryption | XChaCha20-Poly1305, Argon2id, HKDF-SHA256, BLAKE2b |
| Infrastructure | Docker Compose (PostgreSQL, Redis, MinIO, Chrome headless) |

---

## Project Structure

```
any-note/
├── backend/
│   ├── cmd/                # server, worker, migrate entrypoints
│   ├── internal/
│   │   ├── handler/        # HTTP handlers (chi routes)
│   │   ├── service/        # Business logic layer
│   │   ├── repository/     # Data access (PostgreSQL via sqlc)
│   │   ├── config/         # Configuration and env loading
│   │   ├── domain/         # Domain models and types
│   │   ├── llm/            # LLM provider adapters
│   │   ├── platform/       # Publishing platform adapters
│   │   └── queue/          # Background job definitions
│   └── db/                 # SQL migrations and sqlc queries
├── frontend/
│   └── lib/
│       ├── core/           # crypto, database, sync, network, theme
│       ├── features/       # auth, notes, compose, publish, settings, tags
│       └── routing/        # go_router configuration
├── doc/                    # API reference, schema docs, self-hosting guide
├── deploy/                 # Deployment configurations
├── scripts/                # Build and release scripts
├── docker-compose.yml
└── Makefile
```

---

## Quick Start

### Prerequisites

- Go 1.22+
- Flutter 3.41+
- Docker and Docker Compose

### 1. Start infrastructure

```bash
docker compose up -d postgres redis minio chrome
```

### 2. Run the backend

```bash
cd backend && go mod tidy
make dev-server    # API server on :8080
make dev-worker    # Background job worker (separate terminal)
make migrate       # Run database migrations
```

### 3. Run the frontend

```bash
cd frontend && flutter pub get
make dev-frontend
```

### Other useful commands

```bash
make help              # List all available make targets
make test              # Run all tests (backend + frontend)
make generate          # Run sqlc + Drift code generation
make lint              # Lint backend and frontend
make docker-up         # Start all Docker containers
```

---

## API Routes

All routes are prefixed with `/api/v1/`.

| Group | Endpoints |
|-------|-----------|
| Auth | `POST /auth/register`, `/auth/login`, `/auth/refresh`, `/auth/me`, `/auth/account` |
| Sync | `POST /sync/pull`, `/sync/push`, `/sync/status` |
| AI | `POST /ai/proxy`, `GET /ai/quota` |
| LLM | `GET/POST /llm/configs`, `GET /llm/providers` |
| Publish | `POST /publish`, `GET /publish/history` |
| Platforms | `POST /platforms/{platform}/connect`, `/disconnect`, `/verify` |

---

## Testing

```bash
# Backend (668+ tests)
cd backend && go test ./...

# Frontend (608+ tests)
cd frontend && flutter test

# With coverage
make coverage-backend
make coverage-frontend
```

---

## Documentation

| Document | Description |
|----------|-------------|
| `doc/api.md` | Full API reference with request/response examples |
| `doc/database-schema.md` | Database schema and migration history |
| `doc/self-hosting.md` | Self-hosting deployment guide |
| `doc/development-plan.md` | Development roadmap and task status |
| `doc/legal/privacy-policy.md` | Privacy policy |

---

## Security Model

- **Zero-knowledge server** -- The server never possesses encryption keys or plaintext content
- **Per-item key derivation** -- Each note encrypted with a unique key; compromise of one key does not affect others
- **Authenticated encryption** -- XChaCha20-Poly1305 provides confidentiality, integrity, and authenticity
- **Key stretching** -- Argon2id (memory-hard) protects against brute-force on master passwords
- **Forward secrecy** -- Per-item keys limit blast radius of any single key compromise
- **No plaintext logging** -- AI proxy request/response bodies are never logged
- **Rate limiting** -- API rate limiting with LRU eviction to prevent abuse

---

## License

Proprietary. All rights reserved.
