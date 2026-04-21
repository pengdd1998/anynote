package handler

import (
	"testing"

	"github.com/google/uuid"
)

func TestParseUUID_ValidUUID(t *testing.T) {
	input := "550e8400-e29b-41d4-a716-446655440000"
	expected, err := uuid.Parse(input)
	if err != nil {
		t.Fatalf("setup: failed to parse UUID: %v", err)
	}

	got, gotErr := parseUUID(input)
	if gotErr != nil {
		t.Errorf("parseUUID(%q) returned unexpected error: %v", input, gotErr)
	}
	if got != expected {
		t.Errorf("parseUUID(%q) = %v, want %v", input, got, expected)
	}
}

func TestParseUUID_InvalidUUID(t *testing.T) {
	_, gotErr := parseUUID("not-a-uuid")
	if gotErr == nil {
		t.Error(`parseUUID("not-a-uuid") expected error, got nil`)
	}
}

func TestParseUUID_EmptyString(t *testing.T) {
	_, gotErr := parseUUID("")
	if gotErr == nil {
		t.Error(`parseUUID("") expected error, got nil`)
	}
}

func TestParseUUID_UppercaseUUID(t *testing.T) {
	input := "550E8400-E29B-41D4-A716-446655440000"
	expected, err := uuid.Parse(input)
	if err != nil {
		t.Fatalf("setup: failed to parse UUID: %v", err)
	}

	got, gotErr := parseUUID(input)
	if gotErr != nil {
		t.Errorf("parseUUID(%q) returned unexpected error: %v", input, gotErr)
	}
	if got != expected {
		t.Errorf("parseUUID(%q) = %v, want %v", input, got, expected)
	}
}

func TestParseUUID_NilUUID(t *testing.T) {
	input := "00000000-0000-0000-0000-000000000000"
	expected, err := uuid.Parse(input)
	if err != nil {
		t.Fatalf("setup: failed to parse nil UUID: %v", err)
	}

	got, gotErr := parseUUID(input)
	if gotErr != nil {
		t.Errorf("parseUUID(%q) returned unexpected error: %v", input, gotErr)
	}
	if got != expected {
		t.Errorf("parseUUID(%q) = %v, want %v", input, got, expected)
	}
}
