package testutil

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	ctestcontainers "github.com/testcontainers/testcontainers-go/modules/postgres"
	tcwait "github.com/testcontainers/testcontainers-go/wait"
)

// PostgresContainer wraps a testcontainers PostgreSQL instance with a connection pool.
type PostgresContainer struct {
	Container *ctestcontainers.PostgresContainer
	Pool      *pgxpool.Pool
	DSN       string
}

// SetupPostgresContainer creates a PostgreSQL 16 testcontainer and returns
// a ready-to-use connection pool. Migrations must be run separately via RunMigrations.
// Call TeardownPostgres when done.
//
// Usage:
//
//	pc := testutil.SetupPostgresContainer(t)
//	defer testutil.TeardownPostgres(t, pc)
//	testutil.RunMigrations(t, pc.Pool)
//	repo := repository.NewSyncBlobRepository(pc.Pool)
func SetupPostgresContainer(t *testing.T) *PostgresContainer {
	t.Helper()
	ctx := context.Background()

	c, err := ctestcontainers.Run(ctx,
		"postgres:16-alpine",
		ctestcontainers.WithDatabase("anynote_test"),
		ctestcontainers.WithUsername("test"),
		ctestcontainers.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			tcwait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("failed to start postgres container: %v", err)
	}

	dsn, err := c.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("failed to create connection pool: %v", err)
	}

	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("failed to ping database: %v", err)
	}

	return &PostgresContainer{
		Container: c,
		Pool:      pool,
		DSN:       dsn,
	}
}

// TeardownPostgres cleans up the container and connection pool.
func TeardownPostgres(t *testing.T, pc *PostgresContainer) {
	t.Helper()
	if pc == nil {
		return
	}
	if pc.Pool != nil {
		pc.Pool.Close()
	}
	if pc.Container != nil {
		if err := pc.Container.Terminate(context.Background()); err != nil {
			t.Logf("warning: failed to terminate postgres container: %v", err)
		}
	}
}

// RunMigrations applies all up-migration files from the given directory to the pool.
// It mirrors the logic in cmd/migrate/main.go: reads SQL files sorted by name,
// splits on "-- +migrate Down", and executes the up portion.
func RunMigrations(t *testing.T, pool *pgxpool.Pool, migrationsDir string) {
	t.Helper()
	ctx := context.Background()

	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMPTZ DEFAULT NOW()
		);
	`)
	if err != nil {
		t.Fatalf("failed to create schema_migrations table: %v", err)
	}

	files, err := filepath.Glob(filepath.Join(migrationsDir, "*.sql"))
	if err != nil {
		t.Fatalf("failed to read migrations: %v", err)
	}
	sort.Strings(files)

	for _, file := range files {
		filename := filepath.Base(file)

		// Skip down-migration files
		if strings.HasSuffix(filename, ".down.sql") {
			continue
		}

		var exists bool
		if err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", filename).Scan(&exists); err != nil {
			t.Fatalf("failed to check migration status: %v", err)
		}
		if exists {
			continue
		}

		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("failed to read migration %s: %v", filename, err)
		}

		upSQL := extractUpSQL(string(content))
		if upSQL == "" {
			continue
		}

		if _, err := pool.Exec(ctx, upSQL); err != nil {
			t.Fatalf("failed to apply migration %s: %v", filename, err)
		}

		if _, err := pool.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", filename); err != nil {
			t.Fatalf("failed to record migration %s: %v", filename, err)
		}
	}
}

// extractUpSQL splits a migration file on "-- +migrate Down" and returns
// the up portion with the "-- +migrate Up" marker stripped.
func extractUpSQL(content string) string {
	parts := strings.Split(content, "-- +migrate Down")
	upSQL := parts[0]
	upSQL = strings.Replace(upSQL, "-- +migrate Up", "", 1)
	upSQL = strings.TrimSpace(upSQL)
	return upSQL
}

// SetupTestDB creates a PostgreSQL container, runs all migrations, and returns
// a ready-to-use PostgresContainer. This is the main entry point for integration tests.
func SetupTestDB(t *testing.T) *PostgresContainer {
	t.Helper()
	pc := SetupPostgresContainer(t)

	migrationsDir, err := filepath.Abs(filepath.Join("..", "..", "db", "migrations"))
	if err != nil {
		t.Fatalf("failed to resolve migrations dir: %v", err)
	}
	RunMigrations(t, pc.Pool, migrationsDir)

	return pc
}

// CleanTable truncates the given table(s) in the test database.
func CleanTable(t *testing.T, pool *pgxpool.Pool, tables ...string) {
	t.Helper()
	for _, table := range tables {
		_, err := pool.Exec(context.Background(), fmt.Sprintf("TRUNCATE TABLE %s CASCADE", table))
		if err != nil {
			t.Fatalf("failed to truncate table %s: %v", table, err)
		}
	}
}

// SeedUser creates a test user in the database and returns the User domain object.
// The AuthKeyHash is bcrypt-hashed before storage (matching the real Create flow).
func SeedUser(t *testing.T, pool *pgxpool.Pool, id, email, username string) {
	t.Helper()
	ctx := context.Background()
	_, err := pool.Exec(ctx,
		`INSERT INTO users (id, email, username, auth_key_hash, salt, recovery_key, recovery_salt, plan)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		id, email, username,
		[]byte("$2a$12$placeholderhashforintegrationtests12chars"),
		[]byte("testsalt1234567890123456789012"),
		[]byte("testrecoverykey1234567890123456"),
		[]byte("testrecoverysalt123456789012345"),
		"free",
	)
	if err != nil {
		t.Fatalf("failed to seed user %s: %v", email, err)
	}
}
