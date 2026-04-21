package handler

import (
	"fmt"
	"net/http"

	"github.com/google/uuid"
)

func parseUUID(s string) (uuid.UUID, error) {
	id, err := uuid.Parse(s)
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid UUID: %w", err)
	}
	return id, nil
}

// parseUserID extracts the user ID from the request context (set by auth
// middleware) and parses it into a uuid.UUID. Returns an error if the user
// ID is missing or not a valid UUID.
func parseUserID(r *http.Request) (uuid.UUID, error) {
	raw := getUserID(r.Context())
	if raw == "" {
		return uuid.Nil, fmt.Errorf("user ID missing from context")
	}
	return parseUUID(raw)
}
