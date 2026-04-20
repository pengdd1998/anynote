package handler

import (
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestValidateEmail(t *testing.T) {
	tests := []struct {
		name    string
		email   string
		wantErr bool
	}{
		{"valid", "user@example.com", false},
		{"valid_with_dots", "first.last@example.co.uk", false},
		{"valid_with_plus", "user+tag@gmail.com", false},
		{"empty", "", true},
		{"whitespace_only", "   ", true},
		{"no_at", "userexample.com", true},
		{"no_domain", "user@", true},
		{"too_long", string(make([]byte, 255)) + "@x.com", true},
		{"invalid_chars", "user @example.com", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateEmail(tt.email)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateEmail(%q) error = %v, wantErr %v", tt.email, err, tt.wantErr)
			}
		})
	}
}

func TestValidateUUID(t *testing.T) {
	tests := []struct {
		name    string
		id      string
		wantErr bool
	}{
		{"valid", uuid.New().String(), false},
		{"empty", "", true},
		{"invalid", "not-a-uuid", true},
		{"partial", "12345", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateUUID(tt.id)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateUUID(%q) error = %v, wantErr %v", tt.id, err, tt.wantErr)
			}
		})
	}
}

func TestValidatePagination(t *testing.T) {
	tests := []struct {
		name    string
		limit   int
		offset  int
		wantErr bool
	}{
		{"valid", 10, 0, false},
		{"max_limit", 100, 50, false},
		{"zero", 0, 0, false},
		{"negative_limit", -1, 0, true},
		{"negative_offset", 0, -1, true},
		{"limit_exceeds_max", 101, 0, true},
		{"large_limit", 200, 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validatePagination(tt.limit, tt.offset)
			if (err != nil) != tt.wantErr {
				t.Errorf("validatePagination(%d, %d) error = %v, wantErr %v", tt.limit, tt.offset, err, tt.wantErr)
			}
		})
	}
}

func TestValidateRequired(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		field   string
		wantErr bool
	}{
		{"valid", "hello", "field", false},
		{"empty", "", "field", true},
		{"whitespace", "  ", "field", true},
		{"valid_with_spaces", " hello ", "field", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateRequired(tt.value, tt.field)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateRequired(%q, %q) error = %v, wantErr %v", tt.value, tt.field, err, tt.wantErr)
			}
		})
	}
}

func TestValidateUsername(t *testing.T) {
	tests := []struct {
		name     string
		username string
		wantErr  bool
	}{
		{"valid", "john_doe", false},
		{"min_length", "abc", false},
		{"max_length", strings.Repeat("a", 50), false},
		{"empty", "", true},
		{"too_short", "ab", true},
		{"too_long", strings.Repeat("a", 51), true},
		{"whitespace_only", "   ", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateUsername(tt.username)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateUsername(%q) error = %v, wantErr %v", tt.username, err, tt.wantErr)
			}
		})
	}
}

func TestValidationError_Error(t *testing.T) {
	t.Run("with_errors", func(t *testing.T) {
		ve := &ValidationError{Errors: []ValidationErr{{Field: "email", Message: "is required"}}}
		if ve.Error() == "" {
			t.Error("Error() should not be empty")
		}
	})

	t.Run("empty", func(t *testing.T) {
		ve := &ValidationError{}
		if ve.Error() != "validation failed" {
			t.Errorf("Error() = %q, want %q", ve.Error(), "validation failed")
		}
	})
}
