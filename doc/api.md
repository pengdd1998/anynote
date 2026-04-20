# AnyNote API Reference

> **Version**: 1.0
> **Base URL**: `http://localhost:8080`
> **Protocol**: HTTPS recommended for production

---

## Table of Contents

- [Authentication](#authentication)
  - [Headers](#headers)
  - [Authentication Details](#authentication-details)
  - [Rate Limiting](#rate-limiting)
  - [Request Body Size Limits](#request-body-size-limits)
- [1. Authentication (`/api/v1/auth`)](#1-authentication-apiv1auth)
  - [1.1 Register User](#11-register-user)
  - [1.2 Login](#12-login)
  - [1.3 Refresh Token](#13-refresh-token)
  - [1.4 Get Current User](#14-get-current-user)
  - [1.5 Delete Account](#15-delete-account)
- [2. Synchronization (`/api/v1/sync`, `/api/v1/tags`)](#2-synchronization-apiv1sync-apiv1tags)
  - [2.1 Pull Sync Blobs](#21-pull-sync-blobs)
  - [2.2 Push Sync Blobs](#22-push-sync-blobs)
  - [2.3 Get Sync Status](#23-get-sync-status)
  - [2.4 Get Sync Stats](#24-get-sync-stats)
  - [2.5 Get Sync Progress](#25-get-sync-progress)
  - [2.6 List Tags](#26-list-tags)
  - [2.7 Batch Delete Items](#27-batch-delete-items)
- [3. AI Proxy (`/api/v1/ai`)](#3-ai-proxy-apiv1ai)
  - [3.1 AI Chat Proxy](#31-ai-chat-proxy)
  - [3.2 Get AI Quota](#32-get-ai-quota)
- [4. LLM Configuration (`/api/v1/llm`)](#4-llm-configuration-apiv1llm)
  - [4.1 List LLM Configurations](#41-list-llm-configurations)
  - [4.2 Create LLM Configuration](#42-create-llm-configuration)
  - [4.3 Update LLM Configuration](#43-update-llm-configuration)
  - [4.4 Delete LLM Configuration](#44-delete-llm-configuration)
  - [4.5 Test LLM Connection](#45-test-llm-connection)
  - [4.6 List Supported Providers](#46-list-supported-providers)
- [5. Publishing (`/api/v1/publish`)](#5-publishing-apiv1publish)
  - [5.1 Publish Content](#51-publish-content)
  - [5.2 Get Publish History](#52-get-publish-history)
  - [5.3 Get Publish Log](#53-get-publish-log)
- [6. Shared Notes (`/api/v1/share`)](#6-shared-notes-apiv1share)
  - [6.1 Create Shared Note](#61-create-shared-note)
  - [6.2 Get Shared Note](#62-get-shared-note)
  - [6.3 Discovery Feed](#63-discovery-feed)
  - [6.4 Toggle Reaction](#64-toggle-reaction)
- [7. Comments](#7-comments)
  - [7.1 Create Comment](#71-create-comment)
  - [7.2 List Comments](#72-list-comments)
  - [7.3 Delete Comment](#73-delete-comment)
- [8. Platform Connections (`/api/v1/platforms/{platform}`)](#8-platform-connections-apiv1platformsplatform)
  - [8.1 Connect](#81-connect)
  - [8.2 Disconnect](#82-disconnect)
  - [8.3 Verify](#83-verify)
- [9. Device Tokens (`/api/v1/devices`)](#9-device-tokens-apiv1devices)
  - [9.1 Register Device](#91-register-device)
  - [9.2 Unregister Device](#92-unregister-device)
- [10. Health Checks](#10-health-checks)
  - [10.1 Health](#101-health)
  - [10.2 Readiness](#102-readiness)
  - [10.3 Metrics](#103-metrics)
- [Error Responses](#error-responses)
- [Security Notes](#security-notes)

---

## Authentication

### Headers

All authenticated requests require the following headers:

```
Authorization: Bearer {access_token}
Content-Type: application/json
```

### Authentication Details

AnyNote uses JWT-based authentication with a dual-token system:

| Token Type   | Purpose                      | Lifetime |
|--------------|------------------------------|----------|
| Access token | Authenticate API requests    | 1 hour   |
| Refresh token| Obtain new access tokens     | 7 days   |

Key rules:
- Access tokens are required for all authenticated endpoints.
- Refresh tokens are **rejected** for authenticated requests. Only tokens with `token_type == "access"` are accepted.
- Use the [Refresh Token](#13-refresh-token) endpoint to obtain a new access token when the current one expires.

### Rate Limiting

| Endpoint Group          | Limit                  | Scope     |
|-------------------------|------------------------|-----------|
| Auth (register, login, refresh) | 20 requests/minute | Per IP    |
| Sync endpoints          | 30 requests/minute     | Per user  |
| Publish endpoint        | 10 requests/minute     | Per user  |

Rate-limited responses return HTTP `429 Too Many Requests` with a `Retry-After` header.

### Request Body Size Limits

| Endpoint      | Maximum Size |
|---------------|--------------|
| Default       | 10 MB        |
| Sync push     | 50 MB        |

---

## 1. Authentication (`/api/v1/auth`)

### 1.1 Register User

Create a new user account.

```
POST /api/v1/auth/register
```

**Authentication**: Not required.
**Rate limit**: 20 requests/minute per IP.

**Request Body**:

| Field           | Type   | Required | Constraints                                    |
|-----------------|--------|----------|------------------------------------------------|
| `email`         | string | Yes      | Valid email address                            |
| `username`      | string | Yes      | Alphanumeric, underscores, and hyphens (`^[a-zA-Z0-9_-]+$`) |
| `auth_key_hash` | string | Yes      | BLAKE2b hash, max 128 characters               |
| `salt`          | string | Yes      | Max 64 characters                              |
| `recovery_key`  | string | Yes      | Max 1024 characters                            |

**Request Example**:

```json
{
  "email": "user@example.com",
  "username": "alice_notes",
  "auth_key_hash": "a3f5b2c8d1e9...",
  "salt": "c2FsdF92YWx1ZQ==",
  "recovery_key": "eyJrZXkiOiJyZWNvdmVyeSJ9..."
}
```

**Response** `201 Created`:

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600
}
```

**Error Responses**:

| HTTP Status | `error_code`        | Description                        |
|-------------|---------------------|------------------------------------|
| 400         | `validation_error`  | Invalid or missing request fields  |
| 409         | `duplicate_email`   | Email already registered           |
| 409         | `duplicate_username`| Username already taken             |
| 429         | —                   | Rate limit exceeded                |

**Error Example**:

```json
{
  "error_code": "duplicate_email",
  "message": "A user with this email already exists.",
  "details": "email=user@example.com"
}
```

---

### 1.2 Login

Authenticate an existing user and obtain tokens.

```
POST /api/v1/auth/login
```

**Authentication**: Not required.
**Rate limit**: 20 requests/minute per IP.

**Request Body**:

| Field           | Type   | Required | Description          |
|-----------------|--------|----------|----------------------|
| `email`         | string | Yes      | User's email address |
| `auth_key_hash` | string | Yes      | BLAKE2b hash of auth key |

**Request Example**:

```json
{
  "email": "user@example.com",
  "auth_key_hash": "a3f5b2c8d1e9..."
}
```

**Response** `200 OK`:

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600
}
```

**Error Responses**:

| HTTP Status | `error_code`       | Description                  |
|-------------|--------------------|------------------------------|
| 401         | `unauthorized`     | Invalid credentials          |
| 400         | `validation_error` | Missing required fields      |

---

### 1.3 Refresh Token

Exchange a valid refresh token for a new access token.

```
POST /api/v1/auth/refresh
```

**Authentication**: Not required.
**Rate limit**: 20 requests/minute per IP.

**Request Body**:

| Field           | Type   | Required | Description     |
|-----------------|--------|----------|-----------------|
| `refresh_token` | string | Yes      | Valid refresh token |

**Request Example**:

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response** `200 OK`:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600
}
```

**Error Responses**:

| HTTP Status | `error_code`   | Description                       |
|-------------|----------------|-----------------------------------|
| 401         | `unauthorized` | Invalid or expired refresh token  |

---

### 1.4 Get Current User

Retrieve the authenticated user's profile.

```
GET /api/v1/auth/me
```

**Authentication**: Required (Bearer access token).

**Response** `200 OK`:

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "username": "alice_notes",
  "created_at": "2025-06-15T10:30:00Z",
  "plan": "free"
}
```

**Error Responses**:

| HTTP Status | `error_code`   | Description                |
|-------------|----------------|----------------------------|
| 401         | `unauthorized` | Missing or invalid token   |

---

### 1.5 Delete Account

Permanently delete the authenticated user's account and all associated data.

```
DELETE /api/v1/auth/account
```

**Authentication**: Required (Bearer access token).

**Request Body**:

| Field           | Type   | Required | Description                  |
|-----------------|--------|----------|------------------------------|
| `auth_key_hash` | string | Yes      | BLAKE2b hash to confirm identity |

**Request Example**:

```json
{
  "auth_key_hash": "a3f5b2c8d1e9..."
}
```

**Response** `204 No Content`

**Error Responses**:

| HTTP Status | `error_code`   | Description                     |
|-------------|----------------|---------------------------------|
| 401         | `unauthorized` | Invalid auth_key_hash or token  |

> **Warning**: This action is irreversible. All encrypted blobs, LLM configurations, device tokens, and publish history associated with the account are permanently deleted.

---

## 2. Synchronization (`/api/v1/sync`, `/api/v1/tags`)

All sync data is stored as encrypted blobs. The server never stores or processes plaintext user data.

### 2.1 Pull Sync Blobs

Retrieve encrypted blobs that have changed since a given timestamp.

```
GET /api/v1/sync/pull
```

**Authentication**: Required.
**Rate limit**: 30 requests/minute per user.

**Query Parameters**:

| Parameter | Type | Required | Default | Max   | Description                            |
|-----------|------|----------|---------|-------|----------------------------------------|
| `since`   | int  | No       | —       | —     | Unix timestamp for incremental sync    |
| `cursor`  | int  | No       | —       | —     | Pagination cursor from previous response |
| `limit`   | int  | No       | 100     | 500   | Maximum number of items to return      |

**Request Example**:

```
GET /api/v1/sync/pull?since=1713676800&limit=100
```

**Response** `200 OK`:

```json
{
  "blobs": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "item_id": "770e8400-e29b-41d4-a716-446655440002",
      "blob_type": "note",
      "encrypted_blob": "base64encodedencrypteddata...",
      "version": 42,
      "created_at": "2025-06-15T10:30:00Z",
      "updated_at": "2025-06-20T14:22:00Z"
    }
  ],
  "has_more": true,
  "next_cursor": 170
}
```

Use `next_cursor` as the `cursor` parameter in the next request to fetch the next page. When `has_more` is `false`, all items have been retrieved.

---

### 2.2 Push Sync Blobs

Upload encrypted blobs to the server. Uses last-writer-wins (LWW) conflict resolution with version vectors.

```
POST /api/v1/sync/push
```

**Authentication**: Required.
**Rate limit**: 30 requests/minute per user.
**Max body size**: 50 MB.

**Request Body**:

| Field   | Type   | Required | Description                              |
|---------|--------|----------|------------------------------------------|
| `blobs` | array  | Yes      | Array of blob objects (max 1000 items)   |

Each blob object:

| Field             | Type   | Required | Description                     |
|-------------------|--------|----------|---------------------------------|
| `item_id`         | string | Yes      | UUID of the item                |
| `blob_type`       | string | Yes      | Type of blob (e.g. `note`, `tag`, `settings`) |
| `encrypted_blob`  | string | Yes      | Base64-encoded encrypted blob   |
| `version`         | int    | Yes      | Client-side version number      |

**Request Example**:

```json
{
  "blobs": [
    {
      "item_id": "770e8400-e29b-41d4-a716-446655440002",
      "blob_type": "note",
      "encrypted_blob": "base64encodedencrypteddata...",
      "version": 43
    }
  ]
}
```

**Response** `200 OK`:

```json
{
  "synced": 1,
  "conflicts": 0,
  "blobs": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "item_id": "770e8400-e29b-41d4-a716-446655440002",
      "version": 43,
      "status": "synced"
    }
  ]
}
```

**Conflict Handling**: When a conflict is detected (server has a newer version), the response includes items with `"status": "conflict"`. The client must resolve the conflict and re-push.

| `status` Value | Description                                |
|----------------|--------------------------------------------|
| `synced`       | Blob was successfully stored               |
| `conflict`     | Server version is newer; client must resolve |

---

### 2.3 Get Sync Status

Get the current sync status for the authenticated user.

```
GET /api/v1/sync/status
```

**Authentication**: Required.

**Response** `200 OK`:

```json
{
  "last_pull_at": "2025-06-20T14:22:00Z",
  "last_push_at": "2025-06-20T14:25:00Z",
  "pending_pull_count": 5,
  "pending_push_count": 2
}
```

---

### 2.4 Get Sync Stats

Get aggregated statistics about the user's synced data.

```
GET /api/v1/sync/stats
```

**Authentication**: Required.

**Response** `200 OK`:

```json
{
  "total_blobs": 142,
  "total_size_bytes": 2048576,
  "last_sync_at": "2025-06-20T14:25:00Z",
  "blob_type_counts": {
    "note": 120,
    "tag": 15,
    "settings": 7
  }
}
```

---

### 2.5 Get Sync Progress

Check whether a sync operation is currently in progress.

```
GET /api/v1/sync/progress
```

**Authentication**: Required.

**Response** `200 OK`:

```json
{
  "in_progress": true,
  "current_operation": "push",
  "processed_items": 45,
  "total_items": 120
}
```

---

### 2.6 List Tags

Retrieve all tags for the authenticated user.

```
GET /api/v1/tags
```

**Authentication**: Required.

**Response** `200 OK`:

```json
{
  "tags": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "name": "work",
      "color": "#FF5733"
    },
    {
      "id": "880e8400-e29b-41d4-a716-446655440004",
      "name": "personal",
      "color": "#33FF57"
    }
  ]
}
```

---

### 2.7 Batch Delete Items

Delete multiple sync blobs by their item IDs.

```
POST /api/v1/sync/batch-delete
```

**Authentication**: Required.

**Request Body**:

| Field      | Type          | Required | Description                      |
|------------|---------------|----------|----------------------------------|
| `item_ids` | array[string] | Yes      | Array of item UUIDs (max 1000)   |

**Request Example**:

```json
{
  "item_ids": [
    "770e8400-e29b-41d4-a716-446655440002",
    "770e8400-e29b-41d4-a716-446655440005"
  ]
}
```

**Response** `200 OK`:

```json
{
  "deleted": 2
}
```

---

## 3. AI Proxy (`/api/v1/ai`)

The AI proxy allows clients to interact with LLM providers through the AnyNote server. Two modes are supported:

- **Direct proxy**: When the user has configured their own LLM provider, requests are proxied directly.
- **Shared server LLM**: When no user LLM is configured, the server's shared LLM is used with rate limiting and quota enforcement.

### 3.1 AI Chat Proxy

Send messages to an LLM and receive responses.

```
POST /api/v1/ai/proxy
```

**Authentication**: Required.

**Request Body**:

| Field        | Type    | Required | Description                                |
|--------------|---------|----------|--------------------------------------------|
| `messages`   | array   | Yes      | Array of message objects                   |
| `max_tokens` | int     | No       | Maximum response tokens (capped by plan)   |
| `stream`     | boolean | No       | Enable SSE streaming (default: `false`)    |

Each message object:

| Field     | Type   | Required | Description                           |
|-----------|--------|----------|---------------------------------------|
| `role`    | string | Yes      | Message role (`user`, `assistant`, `system`) |
| `content` | string | Yes      | Message content                       |

**Token Limits by Plan**:

| Plan       | Max `max_tokens` |
|------------|-------------------|
| Free       | 4096              |
| Pro        | 16384             |
| Lifetime   | 16384             |

**Request Example (Non-Stream)**:

```json
{
  "messages": [
    { "role": "system", "content": "You are a helpful writing assistant." },
    { "role": "user", "content": "Summarize this note." }
  ],
  "max_tokens": 1024,
  "stream": false
}
```

**Response (Non-Stream)** `200 OK`:

```json
{
  "content": "Here is a summary of your note...",
  "done": true
}
```

**Response (Stream)** `200 OK`:

```
Content-Type: text/event-stream

data: {"content": "Here ", "done": false}
data: {"content": "is a ", "done": false}
data: {"content": "summary.", "done": false}
data: {"done": true}
```

**Error Response** `429 Too Many Requests`:

```json
{
  "error": "quota_exceeded",
  "retry_after": 30,
  "queue_position": 0
}
```

> **Privacy**: AI request and response bodies are never logged on the server.

---

### 3.2 Get AI Quota

Retrieve the current user's AI usage quota.

```
GET /api/v1/ai/quota
```

**Authentication**: Required.

**Response** `200 OK`:

```json
{
  "plan": "free",
  "tokens_used": 15200,
  "tokens_limit": 50000,
  "resets_at": "2025-07-01T00:00:00Z"
}
```

---

## 4. LLM Configuration (`/api/v1/llm`)

Manage user-configured LLM providers. When a user configures their own LLM, the AI proxy routes requests directly to that provider instead of using the shared server LLM.

### 4.1 List LLM Configurations

```
GET /api/v1/llm/configs
```

**Authentication**: Required.

**Response** `200 OK`:

```json
[
  {
    "id": "990e8400-e29b-41d4-a716-446655440006",
    "name": "My OpenAI Config",
    "provider": "openai",
    "base_url": "https://api.openai.com/v1",
    "model": "gpt-4o",
    "created_at": "2025-06-10T08:00:00Z",
    "updated_at": "2025-06-15T12:30:00Z"
  }
]
```

> **Note**: API keys are never returned in responses. They are stored encrypted at rest using AES-256-GCM.

---

### 4.2 Create LLM Configuration

```
POST /api/v1/llm/configs
```

**Authentication**: Required.

**Request Body**:

| Field      | Type   | Required | Description                           |
|------------|--------|----------|---------------------------------------|
| `name`     | string | Yes      | Display name for this configuration   |
| `provider` | string | Yes      | Provider identifier (e.g. `openai`)   |
| `base_url` | string | Yes      | API base URL                          |
| `api_key`  | string | Yes      | API key (encrypted at rest)           |
| `model`    | string | Yes      | Model identifier (e.g. `gpt-4o`)      |

**Request Example**:

```json
{
  "name": "My OpenAI Config",
  "provider": "openai",
  "base_url": "https://api.openai.com/v1",
  "api_key": "sk-...",
  "model": "gpt-4o"
}
```

**Response** `201 Created`: Returns the created configuration (without the API key).

---

### 4.3 Update LLM Configuration

```
PUT /api/v1/llm/configs/{id}
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description              |
|-----------|--------|--------------------------|
| `id`      | string | Configuration UUID       |

**Request Body**: Same fields as [Create LLM Configuration](#42-create-llm-configuration). All fields are optional; only provided fields are updated.

**Response** `200 OK`: Returns the updated configuration.

---

### 4.4 Delete LLM Configuration

```
DELETE /api/v1/llm/configs/{id}
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description              |
|-----------|--------|--------------------------|
| `id`      | string | Configuration UUID       |

**Response** `204 No Content`

---

### 4.5 Test LLM Connection

Validate that an LLM configuration can successfully connect to the provider.

```
POST /api/v1/llm/configs/{id}/test
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description              |
|-----------|--------|--------------------------|
| `id`      | string | Configuration UUID       |

**Response** `200 OK`:

```json
{
  "success": true,
  "message": "Connection successful",
  "model_info": {
    "model": "gpt-4o"
  }
}
```

**Error Response** `200 OK` (test failed, not an HTTP error):

```json
{
  "success": false,
  "message": "Authentication failed: invalid API key"
}
```

---

### 4.6 List Supported Providers

```
GET /api/v1/llm/providers
```

**Authentication**: Not required.

**Response** `200 OK`:

```json
[
  {
    "id": "openai",
    "name": "OpenAI",
    "default_base_url": "https://api.openai.com/v1",
    "models": ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"]
  },
  {
    "id": "anthropic",
    "name": "Anthropic",
    "default_base_url": "https://api.anthropic.com/v1",
    "models": ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
  }
]
```

---

## 5. Publishing (`/api/v1/publish`)

Publish encrypted notes to external platforms (e.g. XHS). Publishing is asynchronous and handled by a background worker.

### 5.1 Publish Content

Submit a note for publishing to an external platform.

```
POST /api/v1/publish
```

**Authentication**: Required.
**Rate limit**: 10 requests/minute per user.

**Request Body**:

| Field            | Type   | Required | Description                          |
|------------------|--------|----------|--------------------------------------|
| `platform`       | string | Yes      | Target platform (e.g. `xhs`)         |
| `content_item_id`| string | Yes      | UUID of the note to publish          |
| `title`          | string | Yes      | Publication title                    |
| `content`        | string | Yes      | Publication content                  |
| `tags`           | array  | No       | Array of tag strings                 |
| `schedule_at`    | string | No       | RFC3339 timestamp for scheduled publish |

**Request Example**:

```json
{
  "platform": "xhs",
  "content_item_id": "770e8400-e29b-41d4-a716-446655440002",
  "title": "My Travel Notes",
  "content": "Today I visited...",
  "tags": ["travel", "photography"],
  "schedule_at": "2025-06-25T09:00:00Z"
}
```

**Response** `202 Accepted`:

```json
{
  "id": "aa0e8400-e29b-41d4-a716-446655440007",
  "status": "pending"
}
```

| `status` Value | Description              |
|----------------|--------------------------|
| `pending`      | Queued for publishing    |
| `processing`   | Currently being published|
| `completed`    | Successfully published   |
| `failed`       | Publishing failed        |

---

### 5.2 Get Publish History

Retrieve the user's publish history.

```
GET /api/v1/publish/history
```

**Authentication**: Required.

**Response** `200 OK`:

```json
[
  {
    "id": "aa0e8400-e29b-41d4-a716-446655440007",
    "platform": "xhs",
    "title": "My Travel Notes",
    "status": "completed",
    "created_at": "2025-06-20T14:00:00Z",
    "completed_at": "2025-06-20T14:02:30Z"
  }
]
```

---

### 5.3 Get Publish Log

Retrieve details for a specific publish operation.

```
GET /api/v1/publish/{id}
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description              |
|-----------|--------|--------------------------|
| `id`      | string | Publish operation UUID   |

**Response** `200 OK`:

```json
{
  "id": "aa0e8400-e29b-41d4-a716-446655440007",
  "platform": "xhs",
  "content_item_id": "770e8400-e29b-41d4-a716-446655440002",
  "title": "My Travel Notes",
  "content": "Today I visited...",
  "tags": ["travel", "photography"],
  "status": "completed",
  "created_at": "2025-06-20T14:00:00Z",
  "completed_at": "2025-06-20T14:02:30Z",
  "error": null,
  "platform_post_id": "xhs_12345"
}
```

---

## 6. Shared Notes (`/api/v1/share`)

Share encrypted notes with other users or the public. Shared note content remains encrypted; the server never has access to plaintext.

### 6.1 Create Shared Note

Create a new shared note link.

```
POST /api/v1/share
```

**Authentication**: Required.

**Request Body**:

| Field             | Type   | Required | Description                           |
|-------------------|--------|----------|---------------------------------------|
| `encrypted_content` | string | Yes    | Base64-encoded encrypted content      |
| `encrypted_title`   | string | Yes    | Base64-encoded encrypted title        |
| `share_key_hash`    | string | Yes    | Hash of the share key                 |
| `expires_at`        | string | No     | RFC3339 timestamp for expiration      |
| `max_views`         | int    | No     | Maximum number of allowed views       |

**Request Example**:

```json
{
  "encrypted_content": "base64encryptedcontent...",
  "encrypted_title": "base64encryptedtitle...",
  "share_key_hash": "b3a1c8d5e7f9...",
  "expires_at": "2025-07-20T00:00:00Z",
  "max_views": 10
}
```

**Response** `201 Created`:

```json
{
  "id": "bb0e8400-e29b-41d4-a716-446655440008",
  "share_url": "https://app.anynote.com/share/bb0e8400-e29b-41d4-a716-446655440008",
  "expires_at": "2025-07-20T00:00:00Z",
  "max_views": 10
}
```

---

### 6.2 Get Shared Note

Retrieve a shared note by ID. No authentication is required; anyone with the link can access it.

```
GET /api/v1/share/{id}
```

**Authentication**: Not required.

**Path Parameters**:

| Parameter | Type   | Description            |
|-----------|--------|------------------------|
| `id`      | string | Shared note UUID       |

**Response** `200 OK`:

```json
{
  "id": "bb0e8400-e29b-41d4-a716-446655440008",
  "encrypted_content": "base64encryptedcontent...",
  "encrypted_title": "base64encryptedtitle...",
  "view_count": 3,
  "created_at": "2025-06-20T14:00:00Z"
}
```

**Error Responses**:

| HTTP Status | `error_code` | Description                   |
|-------------|--------------|-------------------------------|
| 404         | `not_found`  | Shared note does not exist    |
| 410         | `expired`    | Note has expired              |
| 410         | `max_views`  | View limit has been reached   |

---

### 6.3 Discovery Feed

Browse a public feed of shared notes. No authentication required.

```
GET /api/v1/share/discover
```

**Authentication**: Not required.

**Query Parameters**:

| Parameter | Type | Required | Default | Description              |
|-----------|------|----------|---------|--------------------------|
| `limit`   | int  | No       | 20      | Items per page           |
| `offset`  | int  | No       | 0       | Pagination offset        |

**Response** `200 OK`:

```json
{
  "items": [
    {
      "id": "bb0e8400-e29b-41d4-a716-446655440008",
      "encrypted_title": "base64encryptedtitle...",
      "view_count": 42,
      "created_at": "2025-06-20T14:00:00Z"
    }
  ],
  "total": 150
}
```

---

### 6.4 Toggle Reaction

Add or remove a reaction on a shared note.

```
POST /api/v1/share/{id}/react
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description            |
|-----------|--------|------------------------|
| `id`      | string | Shared note UUID       |

**Request Body**:

| Field           | Type   | Required | Description                          |
|-----------------|--------|----------|--------------------------------------|
| `reaction_type` | string | Yes      | `heart` or `bookmark`                |

**Request Example**:

```json
{
  "reaction_type": "heart"
}
```

**Response** `200 OK`:

```json
{
  "reaction_type": "heart",
  "active": true
}
```

Calling the same endpoint again with the same `reaction_type` toggles the reaction off (returns `"active": false`).

---

## 7. Comments

### 7.1 Create Comment

Add a comment to a shared note.

```
POST /api/v1/share/{id}/comments
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description            |
|-----------|--------|------------------------|
| `id`      | string | Shared note UUID       |

**Request Body**:

| Field     | Type   | Required | Description          |
|-----------|--------|----------|----------------------|
| `content` | string | Yes      | Comment text         |

**Request Example**:

```json
{
  "content": "Great note! Thanks for sharing."
}
```

**Response** `201 Created`:

```json
{
  "id": "cc0e8400-e29b-41d4-a716-446655440009",
  "share_id": "bb0e8400-e29b-41d4-a716-446655440008",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "content": "Great note! Thanks for sharing.",
  "created_at": "2025-06-20T15:00:00Z"
}
```

---

### 7.2 List Comments

Retrieve comments for a shared note. No authentication required.

```
GET /api/v1/share/{id}/comments
```

**Authentication**: Not required.

**Path Parameters**:

| Parameter | Type   | Description            |
|-----------|--------|------------------------|
| `id`      | string | Shared note UUID       |

**Query Parameters**:

| Parameter | Type | Required | Default | Description              |
|-----------|------|----------|---------|--------------------------|
| `limit`   | int  | No       | 20      | Comments per page        |
| `offset`  | int  | No       | 0       | Pagination offset        |

**Response** `200 OK`:

```json
{
  "comments": [
    {
      "id": "cc0e8400-e29b-41d4-a716-446655440009",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "alice_notes",
      "content": "Great note! Thanks for sharing.",
      "created_at": "2025-06-20T15:00:00Z"
    }
  ],
  "total": 5
}
```

---

### 7.3 Delete Comment

Delete a comment. Only the comment author can delete their own comments.

```
DELETE /api/v1/comments/{id}
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description            |
|-----------|--------|------------------------|
| `id`      | string | Comment UUID           |

**Response** `204 No Content`

**Error Responses**:

| HTTP Status | `error_code`   | Description                       |
|-------------|----------------|-----------------------------------|
| 403         | `unauthorized` | Not the comment author            |
| 404         | `not_found`    | Comment does not exist            |

---

## 8. Platform Connections (`/api/v1/platforms/{platform}`)

Manage connections to external publishing platforms (e.g. XHS, WeChat). Platform credentials are managed server-side for automated publishing via headless browser.

### 8.1 Connect

Establish a connection to an external platform.

```
POST /api/v1/platforms/{platform}/connect
```

**Authentication**: Required.

**Path Parameters**:

| Parameter  | Type   | Description                       |
|------------|--------|-----------------------------------|
| `platform` | string | Platform identifier (e.g. `xhs`)  |

**Request Body**: Platform-specific credentials or OAuth tokens.

**Response** `200 OK`:

```json
{
  "platform": "xhs",
  "status": "connected",
  "connected_at": "2025-06-20T16:00:00Z"
}
```

---

### 8.2 Disconnect

Remove the connection to an external platform.

```
POST /api/v1/platforms/{platform}/disconnect
```

**Authentication**: Required.

**Path Parameters**:

| Parameter  | Type   | Description                       |
|------------|--------|-----------------------------------|
| `platform` | string | Platform identifier (e.g. `xhs`)  |

**Response** `204 No Content`

---

### 8.3 Verify

Check whether the current platform connection is valid.

```
GET /api/v1/platforms/{platform}/verify
```

**Authentication**: Required.

**Path Parameters**:

| Parameter  | Type   | Description                       |
|------------|--------|-----------------------------------|
| `platform` | string | Platform identifier (e.g. `xhs`)  |

**Response** `200 OK`:

```json
{
  "platform": "xhs",
  "connected": true,
  "verified_at": "2025-06-20T16:05:00Z"
}
```

---

## 9. Device Tokens (`/api/v1/devices`)

Manage push notification device tokens for FCM (Firebase Cloud Messaging).

### 9.1 Register Device

Register or update a device token for push notifications.

```
POST /api/v1/devices
```

**Authentication**: Required.

**Request Body**:

| Field      | Type   | Required | Description                              |
|------------|--------|----------|------------------------------------------|
| `token`    | string | Yes      | FCM device token                         |
| `platform` | string | Yes      | Device platform (`ios`, `android`, `web`) |

**Request Example**:

```json
{
  "token": "fCM_DEVICE_TOKEN_HERE",
  "platform": "android"
}
```

**Response** `200 OK`:

```json
{
  "id": "dd0e8400-e29b-41d4-a716-446655440010",
  "platform": "android",
  "created_at": "2025-06-20T17:00:00Z"
}
```

---

### 9.2 Unregister Device

Remove a device token to stop push notifications for that device.

```
DELETE /api/v1/devices/{token}
```

**Authentication**: Required.

**Path Parameters**:

| Parameter | Type   | Description       |
|-----------|--------|-------------------|
| `token`   | string | FCM device token  |

**Response** `204 No Content`

---

## 10. Health Checks

### 10.1 Health

Basic liveness check.

```
GET /health
```

**Authentication**: Not required.

**Response** `200 OK`:

```json
{
  "status": "healthy",
  "timestamp": "2025-06-20T18:00:00Z",
  "version": "1.0.0"
}
```

---

### 10.2 Readiness

Check whether the service is ready to handle requests, including all dependencies.

```
GET /ready
```

**Authentication**: Not required.

**Response** `200 OK`:

```json
{
  "status": "ready",
  "checks": {
    "db": "ok",
    "redis": "ok",
    "minio": "ok"
  }
}
```

**Response** `503 Service Unavailable` (when a dependency is down):

```json
{
  "status": "not_ready",
  "checks": {
    "db": "ok",
    "redis": "error: connection refused",
    "minio": "ok"
  }
}
```

---

### 10.3 Metrics

Prometheus-format metrics endpoint for monitoring.

```
GET /metrics
```

**Authentication**: Not required.

**Response** `200 OK`: Standard Prometheus text-based exposition format.

---

## Error Responses

All error responses follow a consistent format:

```json
{
  "error_code": "string",
  "message": "string",
  "details": "string"
}
```

### Common Error Codes

| HTTP Status | `error_code`        | Description                              |
|-------------|---------------------|------------------------------------------|
| 400         | `validation_error`  | Invalid or missing request fields        |
| 400         | `invalid_request`   | Malformed request                        |
| 401         | `unauthorized`      | Missing, invalid, or expired token       |
| 403         | `unauthorized`      | Insufficient permissions                 |
| 404         | `not_found`         | Resource not found                       |
| 409         | `duplicate_email`   | Email already registered                 |
| 409         | `duplicate_username`| Username already taken                   |
| 410         | `expired`           | Resource has expired                     |
| 410         | `max_views`         | View limit reached                       |
| 429         | `quota_exceeded`    | Rate limit or usage quota exceeded       |
| 500         | `internal_error`    | Unexpected server error                  |

---

## Security Notes

1. **Zero-knowledge server**: All user data (notes, tags, settings) is stored as encrypted blobs. The server never stores or processes plaintext content.
2. **Encrypted API keys**: User-configured LLM API keys are encrypted at rest using AES-256-GCM.
3. **No request/response body logging**: AI proxy request and response bodies are never logged to protect decrypted note content.
4. **WebSocket origin validation**: All WebSocket connections validate the `Origin` header against a configurable allowlist.
5. **JWT token type enforcement**: Tokens include a `token_type` claim. Access tokens are required for authenticated endpoints; refresh tokens are rejected.
6. **Argon2id key derivation**: Password hashing uses Argon2id with hardened parameters (opsLimitSensitive + memLimitModerate).
7. **Body size limits**: Default 10 MB limit (50 MB for sync push) prevents abuse.
8. **Rate limiting**: Auth, sync, and publish endpoints are rate-limited to prevent brute-force and abuse.
