package repository

import (
	"errors"
	"math"
	"testing"
)

func TestVectorLiteral(t *testing.T) {
	tests := []struct {
		name string
		in   []float64
		want string
		err  bool
	}{
		{"simple", []float64{1, 2, 3}, "[1,2,3]", false},
		{"floats", []float64{0.5, -0.25}, "[0.5,-0.25]", false},
		{"empty", nil, "", true},
		{"nan", []float64{math.NaN()}, "", true},
		{"inf", []float64{math.Inf(-1)}, "", true},
	}
	for _, tc := range tests {
		got, err := vectorLiteral(tc.in)
		if tc.err {
			if err == nil {
				t.Errorf("%s: expected error, got %q", tc.name, got)
			}
			continue
		}
		if err != nil {
			t.Errorf("%s: unexpected error %v", tc.name, err)
			continue
		}
		if got != tc.want {
			t.Errorf("%s: got %q, want %q", tc.name, got, tc.want)
		}
	}
}

func TestEmbeddingSentinel(t *testing.T) {
	if !errors.Is(ErrEmbeddingNotFound, ErrEmbeddingNotFound) {
		t.Error("sentinel should match itself")
	}
}
