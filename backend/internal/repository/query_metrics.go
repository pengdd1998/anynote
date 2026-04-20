package repository

import (
	"log/slog"
	"time"
)

const slowQueryThreshold = 100 * time.Millisecond

// QueryTimer measures the duration of a database query and logs a warning
// if it exceeds the slow-query threshold (100 ms).
//
// Usage:
//
//	defer NewQueryTimer("PullSince", slog.Default())()
func NewQueryTimer(label string, logger *slog.Logger) func() {
	start := time.Now()
	return func() {
		elapsed := time.Since(start)
		if elapsed > slowQueryThreshold {
			logger.Warn("slow query detected",
				slog.String("query", label),
				slog.Duration("elapsed", elapsed),
				slog.Duration("threshold", slowQueryThreshold),
			)
		}
	}
}

// QueryTimerWithCount is like NewQueryTimer but also records the number of
// rows affected. This is useful when the caller wants to log additional
// context about how many rows were processed.
func QueryTimerWithCount(label string, logger *slog.Logger, rowCount int) func() {
	start := time.Now()
	return func() {
		elapsed := time.Since(start)
		if elapsed > slowQueryThreshold {
			logger.Warn("slow query detected",
				slog.String("query", label),
				slog.Int("rows", rowCount),
				slog.Duration("elapsed", elapsed),
				slog.Duration("threshold", slowQueryThreshold),
			)
		}
	}
}
