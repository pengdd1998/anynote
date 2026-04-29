package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	// Initialize logger with default info level for migrate command
	opts := &slog.HandlerOptions{Level: slog.LevelInfo}
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, opts)))

	// DATABASE_URL is required. For local development, export it explicitly:
	//   export DATABASE_URL="postgres://user:pass@localhost:5432/anynote?sslmode=disable"
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		slog.Error("DATABASE_URL environment variable is required but not set")
		fmt.Fprintln(os.Stderr, "Usage: DATABASE_URL=<postgres://...> go run ./cmd/migrate")
		os.Exit(1)
	}

	migrationsDir := "db/migrations"
	if d := os.Getenv("MIGRATIONS_DIR"); d != "" {
		migrationsDir = d
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	// Create migrations tracking table
	_, err = pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMPTZ DEFAULT NOW()
		);
	`)
	if err != nil {
		slog.Error("failed to create migrations table", "error", err)
		os.Exit(1)
	}

	// Read migration files
	files, err := filepath.Glob(filepath.Join(migrationsDir, "*.sql"))
	if err != nil {
		slog.Error("failed to read migrations", "error", err)
		os.Exit(1)
	}

	sort.Strings(files)

	for _, file := range files {
		filename := filepath.Base(file)

		// Skip down-migration files
		if strings.HasSuffix(filename, ".down.sql") {
			continue
		}

		// Check if already applied
		var exists bool
		err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", filename).Scan(&exists)
		if err != nil {
			slog.Error("failed to check migration status", "error", err)
			os.Exit(1)
		}

		if exists {
			slog.Info("skipping already applied migration", "migration", filename)
			continue
		}

		// Read migration file
		content, err := os.ReadFile(file)
		if err != nil {
			slog.Error("failed to read migration", "migration", filename, "error", err)
			os.Exit(1)
		}

		// Split on "-- +migrate Up" and "-- +migrate Down"
		parts := strings.Split(string(content), "-- +migrate Down")
		upSQL := parts[0]
		upSQL = strings.Replace(upSQL, "-- +migrate Up", "", 1)
		upSQL = strings.TrimSpace(upSQL)

		if upSQL == "" {
			slog.Info("skipping empty migration", "migration", filename)
			continue
		}

		// Execute migration
		slog.Info("applying migration", "migration", filename)
		_, err = pool.Exec(ctx, upSQL)
		if err != nil {
			slog.Error("failed to apply migration", "migration", filename, "error", err)
			os.Exit(1)
		}

		// Mark as applied
		_, err = pool.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", filename)
		if err != nil {
			slog.Error("failed to record migration", "migration", filename, "error", err)
			os.Exit(1)
		}

		fmt.Printf("Applied: %s\n", filename)
	}

	slog.Info("all migrations applied successfully")
}
