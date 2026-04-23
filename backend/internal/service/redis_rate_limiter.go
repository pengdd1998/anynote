package service

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisRateLimiter implements distributed rate limiting using Redis
// sorted sets for a sliding window algorithm. Falls back to allowing
// all requests when Redis is unavailable.
type RedisRateLimiter struct {
	client *redis.Client
	limit  int
	window time.Duration
}

// NewRedisRateLimiter creates a new Redis-backed rate limiter.
// Returns an error if the Redis connection cannot be established.
func NewRedisRateLimiter(redisURL string, limit int, window time.Duration) (*RedisRateLimiter, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}

	client := redis.NewClient(opts)

	// Verify connectivity with a short timeout.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping: %w", err)
	}

	return &RedisRateLimiter{
		client: client,
		limit:  limit,
		window: window,
	}, nil
}

// Allow checks if the request for the given key is within rate limits.
// Uses a sliding window algorithm with Redis sorted sets.
// Falls back to true (allow) on Redis errors to avoid blocking traffic.
func (r *RedisRateLimiter) Allow(key string) bool {
	ctx, contextCancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer contextCancel()

	now := time.Now()
	windowStart := now.Add(-r.window)
	member := fmt.Sprintf("%s:%d", key, now.UnixNano())

	pipe := r.client.Pipeline()

	// Remove expired entries.
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%d", windowStart.UnixNano()))

	// Count current window entries.
	countCmd := pipe.ZCard(ctx, key)

	// Add current request.
	pipe.ZAdd(ctx, key, redis.Z{Score: float64(now.UnixNano()), Member: member})

	// Set expiry on the key to auto-clean.
	pipe.Expire(ctx, key, r.window+time.Second)

	if _, err := pipe.Exec(ctx); err != nil {
		// Log but allow on Redis failure to avoid blocking traffic.
		slog.Warn("redis rate limiter error, allowing request", "key", key, "error", err)
		return true
	}

	return countCmd.Val() < int64(r.limit)
}

// Close releases the Redis connection.
func (r *RedisRateLimiter) Close() error {
	return r.client.Close()
}
