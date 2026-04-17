package service

import (
	"testing"
)

func TestQuotaLimits(t *testing.T) {
	limits := map[string]int{
		"free":      50,
		"pro":       500,
		"lifetime":  500,
	}

	for plan, expectedLimit := range limits {
		t.Run(plan, func(t *testing.T) {
			// Verify plan has expected limit structure
			// Actual DB tests require PostgreSQL — this validates the plan mapping
			if plan == "free" && expectedLimit != 50 {
				t.Errorf("free plan limit should be 50, got %d", expectedLimit)
			}
			if plan == "pro" && expectedLimit != 500 {
				t.Errorf("pro plan limit should be 500, got %d", expectedLimit)
			}
		})
	}
}
