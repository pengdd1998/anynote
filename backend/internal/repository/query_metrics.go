package repository

import (
	"log/slog"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

const slowQueryThreshold = 100 * time.Millisecond

// dbQueryDuration tracks database query durations in seconds, labeled by
// the operation name passed to NewQueryTimer / QueryTimerWithCount.
var dbQueryDuration = prometheus.NewHistogramVec(
	prometheus.HistogramOpts{
		Name:    "db_query_duration_seconds",
		Help:    "Histogram of database query durations in seconds, partitioned by operation.",
		Buckets: prometheus.DefBuckets,
	},
	[]string{"query"},
)

func init() {
	prometheus.MustRegister(dbQueryDuration)
}

// NewQueryTimer returns a function that measures the duration of a database query
// and logs a warning if it exceeds the slow-query threshold (100 ms).
//
// Usage:
//
//	defer NewQueryTimer("PullSince", slog.Default())()
func NewQueryTimer(label string, logger *slog.Logger) func() {
	start := time.Now()
	return func() {
		elapsed := time.Since(start)
		dbQueryDuration.WithLabelValues(label).Observe(elapsed.Seconds())
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
		dbQueryDuration.WithLabelValues(label).Observe(elapsed.Seconds())
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
