package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://anynote:anynote_dev@localhost:5432/anynote?sslmode=disable"
	}

	migrationsDir := "db/migrations"
	if d := os.Getenv("MIGRATIONS_DIR"); d != "" {
		migrationsDir = d
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
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
		log.Fatalf("Failed to create migrations table: %v", err)
	}

	// Read migration files
	files, err := filepath.Glob(filepath.Join(migrationsDir, "*.sql"))
	if err != nil {
		log.Fatalf("Failed to read migrations: %v", err)
	}

	sort.Strings(files)

	for _, file := range files {
		filename := filepath.Base(file)

		// Check if already applied
		var exists bool
		err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", filename).Scan(&exists)
		if err != nil {
			log.Fatalf("Failed to check migration status: %v", err)
		}

		if exists {
			log.Printf("Skipping already applied: %s", filename)
			continue
		}

		// Read migration file
		content, err := os.ReadFile(file)
		if err != nil {
			log.Fatalf("Failed to read migration %s: %v", filename, err)
		}

		// Split on "-- +migrate Up" and "-- +migrate Down"
		parts := strings.Split(string(content), "-- +migrate Down")
		upSQL := parts[0]
		upSQL = strings.Replace(upSQL, "-- +migrate Up", "", 1)
		upSQL = strings.TrimSpace(upSQL)

		if upSQL == "" {
			log.Printf("Skipping empty migration: %s", filename)
			continue
		}

		// Execute migration
		log.Printf("Applying: %s", filename)
		_, err = pool.Exec(ctx, upSQL)
		if err != nil {
			log.Fatalf("Failed to apply migration %s: %v", filename, err)
		}

		// Mark as applied
		_, err = pool.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", filename)
		if err != nil {
			log.Fatalf("Failed to record migration %s: %v", filename, err)
		}

		fmt.Printf("Applied: %s\n", filename)
	}

	fmt.Println("All migrations applied successfully")
}
