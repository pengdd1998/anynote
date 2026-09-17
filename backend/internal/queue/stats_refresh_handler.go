package queue

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/service"
	"github.com/hibiken/asynq"
)

// TaskRefreshPostStats is the asynq task name for the hourly stats refresh.
const TaskRefreshPostStats = "refresh:post_stats"

// StatsRefreshHandler iterates recently published posts that carry a
// platform post id and scrapes fresh engagement numbers through the
// platform adapter (when it supports stats). Snapshots land in post_stats.
type StatsRefreshHandler struct {
	registry   *platform.Registry
	publishLog service.PublishLogRepository
	platform   service.PlatformConnectionRepository
	masterKey  []byte

	// lookbackDays bounds how far back stats are still refreshed.
	lookbackDays int
}

// NewStatsRefreshHandler creates the handler.
func NewStatsRefreshHandler(
	registry *platform.Registry,
	publishLog service.PublishLogRepository,
	platform service.PlatformConnectionRepository,
	masterKey []byte,
) *StatsRefreshHandler {
	return &StatsRefreshHandler{
		registry:     registry,
		publishLog:   publishLog,
		platform:     platform,
		masterKey:    masterKey,
		lookbackDays: 30,
	}
}

// HandleRefreshPostStats implements the asynq task.
func (h *StatsRefreshHandler) HandleRefreshPostStats(ctx context.Context, _ *asynq.Task) error {
	logs, err := h.publishLog.ListRecentPublishedWithPostID(ctx, h.lookbackDays)
	if err != nil {
		return fmt.Errorf("list recent published: %w", err)
	}

	refreshed := 0
	for _, l := range logs {
		adapter, aErr := h.registry.Get(l.Platform)
		if aErr != nil {
			continue
		}
		fetcher, ok := adapter.(platform.StatsFetcher)
		if !ok {
			continue // adapter cannot scrape stats
		}

		conn, cErr := h.platform.GetByPlatform(ctx, l.UserID, l.Platform)
		if cErr != nil || len(conn.EncryptedAuth) == 0 {
			continue // connection gone; nothing to scrape with
		}

		stats, sErr := fetcher.FetchStats(ctx, conn.EncryptedAuth, h.masterKey, l.PlatformPostID)
		if sErr != nil {
			slog.Warn("post stats fetch failed",
				"platform", l.Platform, "publish_id", l.ID, "error", sErr,
			)
			continue
		}

		now := time.Now()
		if insErr := h.publishLog.InsertPostStats(ctx, l.ID, stats.Views, stats.Likes, stats.Comments, now); insErr != nil {
			slog.Warn("post stats insert failed", "publish_id", l.ID, "error", insErr)
			continue
		}
		if trimErr := h.publishLog.TrimPostStats(ctx, l.ID, 30); trimErr != nil {
			slog.Warn("post stats trim failed", "publish_id", l.ID, "error", trimErr)
		}
		refreshed++
	}

	if refreshed > 0 {
		slog.Info("post stats refreshed", "posts", refreshed)
	}
	return nil
}
