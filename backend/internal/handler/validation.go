package handler

import (
	"fmt"
	"net/http"
	"regexp"
	"strings"

	"github.com/google/uuid"
)

// ValidationErr represents a single field-level validation failure.
type ValidationErr struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// ValidationError contains one or more field-level validation errors.
type ValidationError struct {
	Errors []ValidationErr `json:"errors"`
}

func (e *ValidationError) Error() string {
	if len(e.Errors) == 0 {
		return "validation failed"
	}
	return fmt.Sprintf("validation failed: %s", e.Errors[0].Message)
}

// writeValidationError writes a 422 Unprocessable Entity response with field details.
func writeValidationError(w http.ResponseWriter, ve *ValidationError) {
	type validationResponse struct {
		Error  string         `json:"error"`
		Errors []ValidationErr `json:"errors"`
	}
	writeJSON(w, http.StatusUnprocessableEntity, validationResponse{
		Error:  "validation_error",
		Errors: ve.Errors,
	})
}

// --- Validators ---

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

// validateEmail checks that the email has a valid format and reasonable length.
func validateEmail(email string) error {
	email = strings.TrimSpace(email)
	if email == "" {
		return &ValidationError{Errors: []ValidationErr{{Field: "email", Message: "Email is required"}}}
	}
	if len(email) > 254 {
		return &ValidationError{Errors: []ValidationErr{{Field: "email", Message: "Email is too long (max 254 characters)"}}}
	}
	if !emailRegex.MatchString(email) {
		return &ValidationError{Errors: []ValidationErr{{Field: "email", Message: "Email format is invalid"}}}
	}
	return nil
}

// validateUUID checks that the string is a valid UUID.
func validateUUID(id string) error {
	if id == "" {
		return &ValidationError{Errors: []ValidationErr{{Field: "id", Message: "ID is required"}}}
	}
	if _, err := uuid.Parse(id); err != nil {
		return &ValidationError{Errors: []ValidationErr{{Field: "id", Message: "Invalid UUID format"}}}
	}
	return nil
}

// validatePagination checks that limit and offset are within bounds.
func validatePagination(limit, offset int) error {
	if limit < 0 || offset < 0 {
		return &ValidationError{Errors: []ValidationErr{{Field: "pagination", Message: "Limit and offset must be non-negative"}}}
	}
	if limit > 100 {
		return &ValidationError{Errors: []ValidationErr{{Field: "limit", Message: "Limit must not exceed 100"}}}
	}
	return nil
}

// validateRequired checks that a required string field is non-empty.
func validateRequired(value, fieldName string) error {
	if strings.TrimSpace(value) == "" {
		return &ValidationError{Errors: []ValidationErr{{Field: fieldName, Message: fmt.Sprintf("%s is required", fieldName)}}}
	}
	return nil
}

// validateUsername checks that the username meets requirements.
func validateUsername(username string) error {
	username = strings.TrimSpace(username)
	if username == "" {
		return &ValidationError{Errors: []ValidationErr{{Field: "username", Message: "Username is required"}}}
	}
	if len(username) < 3 {
		return &ValidationError{Errors: []ValidationErr{{Field: "username", Message: "Username must be at least 3 characters"}}}
	}
	if len(username) > 50 {
		return &ValidationError{Errors: []ValidationErr{{Field: "username", Message: "Username must be at most 50 characters"}}}
	}
	return nil
}
