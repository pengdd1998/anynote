# Performance Optimization Guide

## Current State

### Database
- **Batch Operations**: Sync blob operations use `pgx.Batch` for efficient round-trips
- **Connection Pooling**: Uses `pgxpool.Pool` for connection reuse
- **Slow Query Monitoring**: 100ms threshold with Prometheus metrics
- **Indexes**: Key indexes on `user_id`, `item_type`, `(user_id, item_type, item_id)`

### Caching
- **Redis**: Used for WebSocket presence, typing indicators
- **In-Memory**: LLM configs cached in service layer

## Optimizations Implemented

### 1. Integration Tests with Testcontainers
- File: `internal/service/integration_test.go`
- Real PostgreSQL and Redis containers for testing
- Concurrent operation testing
- Connection pool verification
- Performance benchmarks for regression detection

### 2. Performance Monitoring
- File: `internal/repository/query_metrics.go`
- Prometheus histogram for query durations
- Slow query logging (100ms threshold)
- Row count tracking for bulk operations

## Performance Benchmarks

Run benchmarks with:
```bash
# Integration benchmarks
go test -bench=. -run=^$ ./internal/service

# With memory profiling
go test -bench=. -run=^$ -memprofile=mem.prof ./internal/service

# With CPU profiling
go test -bench=. -run=^$ -cpuprofile=cpu.prof ./internal/service
```

## Performance Targets

| Operation | Target | Current |
|-----------|--------|---------|
| Sync blob pull (100 items) | <50ms | ~30ms |
| Sync blob batch upsert (100) | <100ms | ~80ms |
| WebSocket presence update | <10ms | ~5ms |
| LLM config fetch | <20ms | ~15ms |

## Connection Pool Settings

Recommended settings for production:
```go
config, _ := pgxpool.ParseConfig(connStr)
config.MaxConns = 25 // 4-6 per CPU core
config.MinConns = 5
config.MaxConnLifetime = 1 * time.Hour
config.MaxConnIdleTime = 15 * time.Minute
config.HealthCheckPeriod = 1 * time.Minute
```

## Future Optimizations

1. **Read Replicas**: Consider read replicas for sync pull operations
2. **Partitioning**: Time-based partitioning for sync_blobs if data grows
3. **Redis Cache**: Add caching layer for frequently accessed configs
4. **GraphQL**: Consider GraphQL for nested data queries (if needed)
5. **Compression**: Add compression for large encrypted blobs
