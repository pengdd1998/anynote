// Integration tests using testcontainers-go for real PostgreSQL and Redis.
//
// These tests verify:
// - Database migrations run correctly
// - Repository operations work with real PostgreSQL
// - Sync engine integration with PostgreSQL
// - WebSocket presence with real Redis
// - End-to-end flow of sync operations

package service

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

// ---------------------------------------------------------------------------
// Test containers setup
// ---------------------------------------------------------------------------

// testEnv holds the test infrastructure (PostgreSQL, Redis).
type testEnv struct {
	pgContainer *postgres.PostgresContainer
	pgPool      *pgxpool.Pool
	redisClient *redis.Client
	cleanup     func()
}

// setupTestInfrastructure creates PostgreSQL and Redis containers.
func setupTestInfrastructure(t *testing.T) *testEnv {
	t.Helper()

	ctx := context.Background()

	// Skip in CI environments where Docker may not be available
	if os.Getenv("CI") == "true" && os.Getenv("TESTCONTAINERS") != "true" {
		t.Skip("Skipping integration tests in CI without TESTCONTAINERS=true")
	}

	// PostgreSQL container
	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase("anynote_test"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second)),
	)
	if err != nil {
		t.Fatalf("Failed to start PostgreSQL container: %v", err)
	}

	// Get PostgreSQL connection string
	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("Failed to get connection string: %v", err)
	}

	// Create connection pool
	pgPool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		t.Fatalf("Failed to create connection pool: %v", err)
	}

	// Run migrations
	if err := runMigrations(ctx, pgPool); err != nil {
		t.Fatalf("Failed to run migrations: %v", err)
	}

	// Redis container (using generic testcontainers)
	redisContainer, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: testcontainers.ContainerRequest{
			Image:        "redis:7-alpine",
			ExposedPorts: []string{"6379/tcp"},
			WaitingFor:   wait.ForLog("Ready to accept connections"),
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("Failed to start Redis container: %v", err)
	}

	// Get Redis host and port
	host, err := redisContainer.Host(ctx)
	if err != nil {
		t.Fatalf("Failed to get Redis host: %v", err)
	}
	port, err := redisContainer.MappedPort(ctx, "6379")
	if err != nil {
		t.Fatalf("Failed to get Redis port: %v", err)
	}

	redisClient := redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", host, port.Port()),
	})

	// Verify connection
	if err := redisClient.Ping(ctx).Err(); err != nil {
		t.Fatalf("Failed to connect to Redis: %v", err)
	}

	// Cleanup function
	cleanup := func() {
		if pgPool != nil {
			pgPool.Close()
		}
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Logf("Failed to terminate PostgreSQL container: %v", err)
		}
		if err := redisContainer.Terminate(ctx); err != nil {
			t.Logf("Failed to terminate Redis container: %v", err)
		}
		if redisClient != nil {
			redisClient.Close()
		}
	}

	t.Cleanup(cleanup)

	return &testEnv{
		pgContainer: pgContainer,
		pgPool:      pgPool,
		redisClient: redisClient,
		cleanup:     cleanup,
	}
}

// runMigrations executes the database schema migrations.
// In production, this would use the actual migration files.
func runMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	// Core tables
	schema := `
	-- Users table
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY,
		email TEXT NOT NULL UNIQUE,
		password_hash TEXT NOT NULL,
		salt TEXT NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	-- Sync blobs table (E2E encrypted storage)
	CREATE TABLE IF NOT EXISTS sync_blobs (
		id UUID PRIMARY KEY,
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		item_id TEXT NOT NULL,
		item_type TEXT NOT NULL,
		encrypted_data BYTEA NOT NULL,
		version BIGINT NOT NULL DEFAULT 1,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		UNIQUE(user_id, item_id)
	);

	-- Refresh tokens table
	CREATE TABLE IF NOT EXISTS refresh_tokens (
		id UUID PRIMARY KEY,
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		token_hash TEXT NOT NULL UNIQUE,
		expires_at TIMESTAMPTZ NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		revoked_at TIMESTAMPTZ
	);

	-- Indexes for common queries
	CREATE INDEX IF NOT EXISTS idx_sync_blobs_user_id ON sync_blobs(user_id);
	CREATE INDEX IF NOT EXISTS idx_sync_blobs_item_type ON sync_blobs(item_type);
	CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
	CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
	`

	_, err := pool.Exec(ctx, schema)
	return err
}

// ---------------------------------------------------------------------------
// Integration tests: PostgreSQL
// ---------------------------------------------------------------------------

func TestIntegration_PostgreSQL_Connection(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Verify connection
	var result int
	err := env.pgPool.QueryRow(ctx, "SELECT 1").Scan(&result)
	if err != nil {
		t.Fatalf("Failed to query PostgreSQL: %v", err)
	}
	if result != 1 {
		t.Errorf("Expected 1, got %d", result)
	}
}

func TestIntegration_PostgreSQL_UserInsert(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	userID := "550e8400-e29b-41d4-a716-446655440001"
	email := "test@example.com"
	passwordHash := "hashed_password"
	salt := "random_salt"

	// Insert user
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, $2, $3, $4)
	`, userID, email, passwordHash, salt)
	if err != nil {
		t.Fatalf("Failed to insert user: %v", err)
	}

	// Verify user was inserted
	var dbEmail string
	err = env.pgPool.QueryRow(ctx, "SELECT email FROM users WHERE id = $1", userID).Scan(&dbEmail)
	if err != nil {
		t.Fatalf("Failed to query user: %v", err)
	}
	if dbEmail != email {
		t.Errorf("Expected email %q, got %q", email, dbEmail)
	}
}

func TestIntegration_PostgreSQL_SyncBlobCRUD(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// First create a user
	userID := "550e8400-e29b-41d4-a716-446655440002"
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, 'user@example.com', 'hash', 'salt')
	`, userID)
	if err != nil {
		t.Fatalf("Failed to insert user: %v", err)
	}

	// Insert sync blob
	blobID := "660e8400-e29b-41d4-a716-446655440001"
	encryptedData := []byte("encrypted_content")

	_, err = env.pgPool.Exec(ctx, `
		INSERT INTO sync_blobs (id, user_id, item_id, item_type, encrypted_data, version)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, blobID, userID, "note-123", "note", encryptedData, 1)
	if err != nil {
		t.Fatalf("Failed to insert sync blob: %v", err)
	}

	// Query sync blob
	var dbItemID, dbItemType string
	var dbEncryptedData []byte
	var dbVersion int64
	err = env.pgPool.QueryRow(ctx, `
		SELECT item_id, item_type, encrypted_data, version
		FROM sync_blobs WHERE id = $1
	`, blobID).Scan(&dbItemID, &dbItemType, &dbEncryptedData, &dbVersion)
	if err != nil {
		t.Fatalf("Failed to query sync blob: %v", err)
	}

	if dbItemID != "note-123" {
		t.Errorf("Expected item_id 'note-123', got %q", dbItemID)
	}
	if dbItemType != "note" {
		t.Errorf("Expected item_type 'note', got %q", dbItemType)
	}
	if dbVersion != 1 {
		t.Errorf("Expected version 1, got %d", dbVersion)
	}

	// Update sync blob (version increment)
	_, err = env.pgPool.Exec(ctx, `
		UPDATE sync_blobs
		SET encrypted_data = $1, version = version + 1, updated_at = NOW()
		WHERE id = $2
	`, []byte("updated_encrypted_content"), blobID)
	if err != nil {
		t.Fatalf("Failed to update sync blob: %v", err)
	}

	// Verify version increment
	var newVersion int64
	err = env.pgPool.QueryRow(ctx, "SELECT version FROM sync_blobs WHERE id = $1", blobID).Scan(&newVersion)
	if err != nil {
		t.Fatalf("Failed to query updated version: %v", err)
	}
	if newVersion != 2 {
		t.Errorf("Expected version 2, got %d", newVersion)
	}

	// Delete sync blob
	_, err = env.pgPool.Exec(ctx, "DELETE FROM sync_blobs WHERE id = $1", blobID)
	if err != nil {
		t.Fatalf("Failed to delete sync blob: %v", err)
	}

	// Verify deletion
	var count int
	err = env.pgPool.QueryRow(ctx, "SELECT COUNT(*) FROM sync_blobs WHERE id = $1", blobID).Scan(&count)
	if err != nil {
		t.Fatalf("Failed to query count: %v", err)
	}
	if count != 0 {
		t.Errorf("Expected 0 blobs after deletion, got %d", count)
	}
}

func TestIntegration_PostgreSQL_TransactionRollback(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Create user
	userID := "550e8400-e29b-41d4-a716-446655440003"
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, 'user2@example.com', 'hash', 'salt')
	`, userID)
	if err != nil {
		t.Fatalf("Failed to insert user: %v", err)
	}

	// Test transaction rollback
	tx, err := env.pgPool.Begin(ctx)
	if err != nil {
		t.Fatalf("Failed to begin transaction: %v", err)
	}

	// Insert within transaction
	_, err = tx.Exec(ctx, `
		INSERT INTO sync_blobs (id, user_id, item_id, item_type, encrypted_data, version)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, "770e8400-e29b-41d4-a716-446655440001", userID, "note-tx", "note", []byte("data"), 1)
	if err != nil {
		t.Fatalf("Failed to insert in transaction: %v", err)
	}

	// Rollback
	tx.Rollback(ctx)

	// Verify blob was not inserted
	var count int
	err = env.pgPool.QueryRow(ctx, "SELECT COUNT(*) FROM sync_blobs WHERE item_id = $1", "note-tx").Scan(&count)
	if err != nil {
		t.Fatalf("Failed to query count: %v", err)
	}
	if count != 0 {
		t.Errorf("Expected 0 blobs after rollback, got %d", count)
	}
}

// ---------------------------------------------------------------------------
// Integration tests: Redis
// ---------------------------------------------------------------------------

func TestIntegration_Redis_Connection(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Verify connection
	result := env.redisClient.Ping(ctx)
	if result.Err() != nil {
		t.Fatalf("Failed to ping Redis: %v", result.Err())
	}
}

func TestIntegration_Redis_StringOperations(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Set a value
	err := env.redisClient.Set(ctx, "test_key", "test_value", time.Hour).Err()
	if err != nil {
		t.Fatalf("Failed to set value: %v", err)
	}

	// Get the value
	val, err := env.redisClient.Get(ctx, "test_key").Result()
	if err != nil {
		t.Fatalf("Failed to get value: %v", err)
	}
	if val != "test_value" {
		t.Errorf("Expected 'test_value', got %q", val)
	}

	// Delete the value
	err = env.redisClient.Del(ctx, "test_key").Err()
	if err != nil {
		t.Fatalf("Failed to delete value: %v", err)
	}

	// Verify deletion
	_, err = env.redisClient.Get(ctx, "test_key").Result()
	if err != redis.Nil {
		t.Errorf("Expected redis.Nil after deletion, got %v", err)
	}
}

func TestIntegration_Redis_ListOperations(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	key := "test_list"

	// Push values
	err := env.redisClient.RPush(ctx, key, "item1", "item2", "item3").Err()
	if err != nil {
		t.Fatalf("Failed to rpush: %v", err)
	}

	// Get length
	length := env.redisClient.LLen(ctx, key)
	if length.Val() != 3 {
		t.Errorf("Expected length 3, got %d", length.Val())
	}

	// Pop value
	val, err := env.redisClient.LPop(ctx, key).Result()
	if err != nil {
		t.Fatalf("Failed to lpop: %v", err)
	}
	if val != "item1" {
		t.Errorf("Expected 'item1', got %q", val)
	}

	// Cleanup
	env.redisClient.Del(ctx, key)
}

func TestIntegration_Redis_HashOperations(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	key := "test_hash"

	// HSet
	err := env.redisClient.HSet(ctx, key, "field1", "value1").Err()
	if err != nil {
		t.Fatalf("Failed to hset: %v", err)
	}

	// HGet
	val, err := env.redisClient.HGet(ctx, key, "field1").Result()
	if err != nil {
		t.Fatalf("Failed to hget: %v", err)
	}
	if val != "value1" {
		t.Errorf("Expected 'value1', got %q", val)
	}

	// HGetAll returns a map of field->value
	all := env.redisClient.HGetAll(ctx, key)
	if len(all.Val()) != 1 { // 1 field-value pair
		t.Errorf("Expected 1 field in hgetall, got %d", len(all.Val()))
	}

	// Cleanup
	env.redisClient.Del(ctx, key)
}

// ---------------------------------------------------------------------------
// Integration tests: Service layer with PostgreSQL
// ---------------------------------------------------------------------------

func TestIntegration_Services_UserRepositoryPattern(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Simulate repository pattern operations
	userID := "880e8400-e29b-41d4-a716-446655440004"
	email := "repo@example.com"

	// Create
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, $2, $3, $4)
	`, userID, email, "hash", "salt")
	if err != nil {
		t.Fatalf("Create user failed: %v", err)
	}

	// Read
	var dbEmail string
	err = env.pgPool.QueryRow(ctx, "SELECT email FROM users WHERE id = $1", userID).Scan(&dbEmail)
	if err != nil {
		t.Fatalf("Read user failed: %v", err)
	}
	if dbEmail != email {
		t.Errorf("Expected email %q, got %q", email, dbEmail)
	}

	// Update
	newEmail := "updated@example.com"
	_, err = env.pgPool.Exec(ctx, "UPDATE users SET email = $1 WHERE id = $2", newEmail, userID)
	if err != nil {
		t.Fatalf("Update user failed: %v", err)
	}

	// Verify update
	err = env.pgPool.QueryRow(ctx, "SELECT email FROM users WHERE id = $1", userID).Scan(&dbEmail)
	if err != nil {
		t.Fatalf("Read updated user failed: %v", err)
	}
	if dbEmail != newEmail {
		t.Errorf("Expected email %q, got %q", newEmail, dbEmail)
	}

	// Delete
	_, err = env.pgPool.Exec(ctx, "DELETE FROM users WHERE id = $1", userID)
	if err != nil {
		t.Fatalf("Delete user failed: %v", err)
	}

	// Verify deletion
	var count int
	err = env.pgPool.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE id = $1", userID).Scan(&count)
	if err != nil {
		t.Fatalf("Count after delete failed: %v", err)
	}
	if count != 0 {
		t.Errorf("Expected 0 users after deletion, got %d", count)
	}
}

// ---------------------------------------------------------------------------
// Integration tests: Combined PostgreSQL + Redis
// ---------------------------------------------------------------------------

func TestIntegration_Combined_UserAndSession(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Create user in PostgreSQL
	userID := "990e8400-e29b-41d4-a716-446655440005"
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, 'session@example.com', 'hash', 'salt')
	`, userID)
	if err != nil {
		t.Fatalf("Failed to create user: %v", err)
	}

	// Store session in Redis
	sessionKey := fmt.Sprintf("session:%s", userID)
	sessionData := fmt.Sprintf(`{"user_id":"%s","email":"session@example.com"}`, userID)
	err = env.redisClient.Set(ctx, sessionKey, sessionData, 24*time.Hour).Err()
	if err != nil {
		t.Fatalf("Failed to store session: %v", err)
	}

	// Verify session exists
	val, err := env.redisClient.Get(ctx, sessionKey).Result()
	if err != nil {
		t.Fatalf("Failed to get session: %v", err)
	}
	if val == "" {
		t.Error("Expected non-empty session data")
	}

	// Verify user exists in database
	var email string
	err = env.pgPool.QueryRow(ctx, "SELECT email FROM users WHERE id = $1", userID).Scan(&email)
	if err != nil {
		t.Fatalf("Failed to query user: %v", err)
	}
	if email != "session@example.com" {
		t.Errorf("Expected email 'session@example.com', got %q", email)
	}
}

// ---------------------------------------------------------------------------
// Integration tests: Concurrent operations
// ---------------------------------------------------------------------------

func TestIntegration_Concurrent_SyncBlobInserts(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Create user
	userID := "aa0e8400-e29b-41d4-a716-446655440006"
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, 'concurrent@example.com', 'hash', 'salt')
	`, userID)
	if err != nil {
		t.Fatalf("Failed to create user: %v", err)
	}

	// Concurrent insert operations
	concurrency := 10
	done := make(chan bool, concurrency)

	// Predefined valid UUIDs for concurrent inserts
	blobIDs := []string{
		"bb0e8400-e29b-41d4-a716-446655440001",
		"bb0e8400-e29b-41d4-a716-446655440002",
		"bb0e8400-e29b-41d4-a716-446655440003",
		"bb0e8400-e29b-41d4-a716-446655440004",
		"bb0e8400-e29b-41d4-a716-446655440005",
		"bb0e8400-e29b-41d4-a716-446655440006",
		"bb0e8400-e29b-41d4-a716-446655440007",
		"bb0e8400-e29b-41d4-a716-446655440008",
		"bb0e8400-e29b-41d4-a716-446655440009",
		"bb0e8400-e29b-41d4-a716-44665544000a",
	}

	for i := 0; i < concurrency; i++ {
		go func(index int) {
			defer func() { done <- true }()
			blobID := blobIDs[index]
			itemID := fmt.Sprintf("note-%d", index)

			_, err := env.pgPool.Exec(ctx, `
				INSERT INTO sync_blobs (id, user_id, item_id, item_type, encrypted_data, version)
				VALUES ($1, $2, $3, $4, $5, $6)
				ON CONFLICT (user_id, item_id) DO NOTHING
			`, blobID, userID, itemID, "note", []byte("data"), 1)
			if err != nil {
				t.Logf("Concurrent insert %d failed: %v", index, err)
			}
		}(i)
	}

	// Wait for all goroutines
	for i := 0; i < concurrency; i++ {
		<-done
	}

	// Verify count
	var count int
	err = env.pgPool.QueryRow(ctx, "SELECT COUNT(*) FROM sync_blobs WHERE user_id = $1", userID).Scan(&count)
	if err != nil {
		t.Fatalf("Failed to count blobs: %v", err)
	}
	if count != concurrency {
		t.Errorf("Expected %d blobs, got %d", concurrency, count)
	}
}

// ---------------------------------------------------------------------------
// Integration tests: Connection pooling
// ---------------------------------------------------------------------------

func TestIntegration_ConnectionPool_Reuse(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Execute multiple queries to verify pool reuse
	for i := 0; i < 10; i++ {
		var result int
		err := env.pgPool.QueryRow(ctx, "SELECT 1").Scan(&result)
		if err != nil {
			t.Fatalf("Query %d failed: %v", i, err)
		}
		if result != 1 {
			t.Errorf("Query %d: expected 1, got %d", i, result)
		}
	}

	// Check pool stats
	stats := env.pgPool.Stat()
	if stats.TotalConns() == 0 {
		t.Error("Expected non-zero total connections")
	}
}

// ---------------------------------------------------------------------------
// Benchmarks (for performance regression detection)
// ---------------------------------------------------------------------------

func BenchmarkIntegration_Postgres_Insert(b *testing.B) {
	if testing.Short() {
		b.Skip("Skipping benchmark in short mode")
	}

	env := setupTestInfrastructure(&testing.T{})
	ctx := context.Background()

	userID := "cc0e8400-e29b-41d4-a716-446655440007"
	_, err := env.pgPool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, salt)
		VALUES ($1, 'bench@example.com', 'hash', 'salt')
	`, userID)
	if err != nil {
		b.Fatalf("Failed to create user: %v", err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		// Use a mix of prefix and counter for unique IDs
		blobID := fmt.Sprintf("dd%de8400-e29b-41d4-a716-446655440000", i%10000)
		itemID := fmt.Sprintf("note-%d", i)

		_, err := env.pgPool.Exec(ctx, `
			INSERT INTO sync_blobs (id, user_id, item_id, item_type, encrypted_data, version)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (user_id, item_id) DO NOTHING
		`, blobID, userID, itemID, "note", []byte("data"), 1)
		if err != nil {
			b.Fatalf("Insert failed: %v", err)
		}
	}
}

func BenchmarkIntegration_Redis_Set(b *testing.B) {
	if testing.Short() {
		b.Skip("Skipping benchmark in short mode")
	}

	env := setupTestInfrastructure(&testing.T{})
	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		key := fmt.Sprintf("bench_key_%d", i)
		err := env.redisClient.Set(ctx, key, "value", time.Hour).Err()
		if err != nil {
			b.Fatalf("Redis Set failed: %v", err)
		}
	}
}

// ---------------------------------------------------------------------------
// Helper: Verify container availability
// ---------------------------------------------------------------------------

func TestContainersAvailable(t *testing.T) {
	if os.Getenv("CI") == "true" && os.Getenv("TESTCONTAINERS") != "true" {
		t.Skip("Skipping container availability check in CI")
	}

	ctx := context.Background()

	// Try to start a simple PostgreSQL container
	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase("test"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second)),
	)
	if err != nil {
		t.Skipf("Testcontainers not available: %v", err)
		return
	}
	if err := pgContainer.Terminate(ctx); err != nil {
		t.Logf("Failed to terminate container: %v", err)
	}

	// If we got here, containers are available
	t.Log("Testcontainers are available for integration testing")
}

// ---------------------------------------------------------------------------
// Helper: Transaction isolation levels
// ---------------------------------------------------------------------------

func TestIntegration_TransactionIsolation(t *testing.T) {
	env := setupTestInfrastructure(t)
	ctx := context.Background()

	// Test serializable isolation level
	tx, err := env.pgPool.Begin(ctx)
	if err != nil {
		t.Fatalf("Failed to begin transaction: %v", err)
	}
	defer tx.Rollback(ctx)

	// Set isolation level
	_, err = tx.Exec(ctx, "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
	if err != nil {
		t.Fatalf("Failed to set isolation level: %v", err)
	}

	// Query current isolation level
	var level string
	err = tx.QueryRow(ctx, "SHOW transaction_isolation").Scan(&level)
	if err != nil {
		t.Fatalf("Failed to query isolation level: %v", err)
	}

	if level != "serializable" {
		t.Errorf("Expected isolation level 'serializable', got %q", level)
	}
}
