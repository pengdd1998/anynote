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

	got := parseUUID(input)
	if got != expected {
		t.Errorf("parseUUID(%q) = %v, want %v", input, got, expected)
	}
}

func TestParseUUID_InvalidUUID(t *testing.T) {
	got := parseUUID("not-a-uuid")
	if got != uuid.Nil {
		t.Errorf("parseUUID(\"not-a-uuid\") = %v, want uuid.Nil", got)
	}
}

func TestParseUUID_EmptyString(t *testing.T) {
	got := parseUUID("")
	if got != uuid.Nil {
		t.Errorf("parseUUID(\"\") = %v, want uuid.Nil", got)
	}
}

func TestParseUUID_UppercaseUUID(t *testing.T) {
	input := "550E8400-E29B-41D4-A716-446655440000"
	expected, err := uuid.Parse(input)
	if err != nil {
		t.Fatalf("setup: failed to parse UUID: %v", err)
	}

	got := parseUUID(input)
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

	got := parseUUID(input)
	if got != expected {
		t.Errorf("parseUUID(%q) = %v, want %v", input, got, expected)
	}
}
