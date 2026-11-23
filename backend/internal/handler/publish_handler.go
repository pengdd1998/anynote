package handler

import (
	"encoding/json"
	"net/http"
	"unicode/utf8"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/platform/spec"
	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const (
	maxPublishTitleLen   = 500
	maxPublishContentLen = 10_000_000 // 10 MB
	maxPublishTags       = 50
	maxPublishTagLen     = 100
)

type PublishHandler struct {
	publishService service.PublishService
}

type publishRequest struct {
	Platform      string   `json:"platform"`
	ContentItemID string   `json:"content_item_id"`
	Title         string   `json:"title"`
	Content       string   `json:"content"`
	Tags          []string `json:"tags"`
	ScheduleAt    *string  `json:"schedule_at,omitempty"`
}

func (h *PublishHandler) Publish(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req publishRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// An optional reference to the generated-content item this post came
	// from. Publishing straight from a note or a draft has none, so it must
	// not be required (requiring it made every client publish fail with 400).
	if req.ContentItemID != "" {
		if _, err := uuid.Parse(req.ContentItemID); err != nil {
			writeError(w, r, http.StatusBadRequest, "validation_error", "content_item_id must be a valid UUID")
			return
		}
	}

	if req.Platform == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Platform is required")
		return
	}

	if !h.publishService.IsValidPlatform(req.Platform) {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Unsupported platform")
		return
	}

	if req.Title == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Title is required")
		return
	}

	if req.Content == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Content is required")
		return
	}

	if utf8.RuneCountInString(req.Title) > maxPublishTitleLen {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Title must be at most 500 characters")
		return
	}

	if len(req.Content) > maxPublishContentLen {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Content must be at most 10 MB")
		return
	}

	if len(req.Tags) > maxPublishTags {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Too many tags (max 50)")
		return
	}
	for _, tag := range req.Tags {
		if len(tag) > maxPublishTagLen {
			writeError(w, r, http.StatusBadRequest, "validation_error", "Tag too long (max 100 characters each)")
			return
		}
	}

	errs, warnings := checkPlatformSpec(req.Platform, req.Title, req.Content, req.Tags)
	if len(errs) > 0 {
		writeValidationProblems(w, r, "validation_error", errs[0].Message, toDomainProblems(errs))
		return
	}

	log, err := h.publishService.Publish(r.Context(), userID, service.PublishRequest{
		Platform:      req.Platform,
		ContentItemID: req.ContentItemID,
		Title:         req.Title,
		Content:       req.Content,
		Tags:          req.Tags,
	})
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "publish_error", "Failed to publish")
		return
	}

	// Strip encrypted content from the response. The publish service stores
	// Title and Content as AES-256-GCM encrypted blobs; the client should
	// never receive these ciphertexts.
	log.Title = ""
	log.Content = ""

	if len(warnings) > 0 {
		writeJSON(w, http.StatusAccepted, struct {
			*domain.PublishLog
			Warnings []spec.Problem `json:"warnings,omitempty"`
		}{log, warnings})
		return
	}

	writeJSON(w, http.StatusAccepted, log)
}

// checkPlatformSpec applies the publishing rules of [platform]. The first
// slice holds findings that block the publish, the second the advisory ones.
// A platform without a declared spec has no platform-specific findings.
func checkPlatformSpec(platform, title, content string, tags []string) (errors, warnings []spec.Problem) {
	platformSpec, ok := spec.For(platform)
	if !ok {
		return nil, nil
	}
	problems := spec.Validate(platformSpec, title, content, tags)
	return spec.Errors(problems), spec.Warnings(problems)
}

func toDomainProblems(problems []spec.Problem) []domain.ValidationProblem {
	out := make([]domain.ValidationProblem, len(problems))
	for i, p := range problems {
		out[i] = domain.ValidationProblem{
			Field:    p.Field,
			Severity: string(p.Severity),
			Message:  p.Message,
		}
	}
	return out
}

// Platforms lists every platform that can be published to together with its
// rules: the limits an editor enforces while the user types, and the writing
// brief the AI composition step follows. Rules live in one place
// (internal/platform/spec) and reach the client only through here.
func (h *PublishHandler) Platforms(w http.ResponseWriter, r *http.Request) {
	if _, err := parseUserID(r); err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	writeJSON(w, http.StatusOK, spec.Guides())
}

// Validate runs the publish checks without publishing anything, so an editor
// can show what is wrong while the user is still writing. Empty fields are
// reported as problems rather than rejected up front.
func (h *PublishHandler) Validate(w http.ResponseWriter, r *http.Request) {
	if _, err := parseUserID(r); err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req publishRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}
	if req.Platform == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Platform is required")
		return
	}
	if !h.publishService.IsValidPlatform(req.Platform) {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Unsupported platform")
		return
	}

	errs, warns := checkPlatformSpec(req.Platform, req.Title, req.Content, req.Tags)
	writeJSON(w, http.StatusOK, validationResponse{
		Valid:    len(errs) == 0,
		Problems: append(toDomainProblems(errs), toDomainProblems(warns)...),
	})
}

type validationResponse struct {
	Valid    bool                       `json:"valid"`
	Problems []domain.ValidationProblem `json:"problems"`
}

func (h *PublishHandler) History(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	logs, err := h.publishService.GetHistory(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "history_error", "Failed to get history")
		return
	}

	writeJSON(w, http.StatusOK, logs)
}

func (h *PublishHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Publish log ID is required")
		return
	}

	parsedID, err := parseUUID(id)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_id", "Invalid publish log ID format")
		return
	}

	log, err := h.publishService.GetByID(r.Context(), userID, parsedID)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusNotFound, "not_found", "Publish log not found")
		}
		return
	}

	writeJSON(w, http.StatusOK, log)
}
