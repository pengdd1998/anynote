package repository

import (
	"bytes"
	"log/slog"
	"strings"
	"testing"
	"time"
)

// captureLogger creates an slog.Logger that writes to a buffer and returns
// both the logger and the buffer so tests can inspect the output.
func captureLogger() (*slog.Logger, *bytes.Buffer) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&buf, nil))
	return logger, &buf
}

func TestNewQueryTimer_FastQuery_NoWarning(t *testing.T) {
	logger, buf := captureLogger()

	done := NewQueryTimer("FastQuery", logger)
	// Complete immediately -- well under the 100ms threshold.
	done()

	output := buf.String()
	if strings.Contains(output, "slow query detected") {
		t.Errorf("fast query should not log a warning, but got: %s", output)
	}
}

func TestNewQueryTimer_SlowQuery_LogsWarning(t *testing.T) {
	logger, buf := captureLogger()

	done := NewQueryTimer("SlowQuery", logger)
	// Sleep past the 100ms threshold.
	time.Sleep(120 * time.Millisecond)
	done()

	output := buf.String()
	if !strings.Contains(output, "slow query detected") {
		t.Errorf("slow query should log a warning, but output was: %s", output)
	}
	if !strings.Contains(output, "SlowQuery") {
		t.Errorf("log should contain query label 'SlowQuery', got: %s", output)
	}
	if !strings.Contains(output, "elapsed") {
		t.Errorf("log should contain 'elapsed' field, got: %s", output)
	}
	if !strings.Contains(output, "threshold") {
		t.Errorf("log should contain 'threshold' field, got: %s", output)
	}
}

func TestNewQueryTimer_LabelInLogOutput(t *testing.T) {
	logger, buf := captureLogger()

	label := "PullSince"
	done := NewQueryTimer(label, logger)
	time.Sleep(120 * time.Millisecond)
	done()

	output := buf.String()
	if !strings.Contains(output, label) {
		t.Errorf("log output should contain label %q, got: %s", label, output)
	}
}

func TestQueryTimerWithCount_FastQuery_NoWarning(t *testing.T) {
	logger, buf := captureLogger()

	done := QueryTimerWithCount("FastCountQuery", logger, 42)
	done()

	output := buf.String()
	if strings.Contains(output, "slow query detected") {
		t.Errorf("fast query should not log a warning, but got: %s", output)
	}
}

func TestQueryTimerWithCount_SlowQuery_IncludesRowCount(t *testing.T) {
	logger, buf := captureLogger()

	rowCount := 1500
	done := QueryTimerWithCount("SlowCountQuery", logger, rowCount)
	time.Sleep(120 * time.Millisecond)
	done()

	output := buf.String()
	if !strings.Contains(output, "slow query detected") {
		t.Errorf("slow query should log a warning, but output was: %s", output)
	}
	if !strings.Contains(output, "SlowCountQuery") {
		t.Errorf("log should contain query label 'SlowCountQuery', got: %s", output)
	}
	if !strings.Contains(output, "rows") {
		t.Errorf("log should contain 'rows' field, got: %s", output)
	}
}

func TestQueryTimerWithCount_SlowQuery_ContainsAllFields(t *testing.T) {
	logger, buf := captureLogger()

	done := QueryTimerWithCount("BulkUpsert", logger, 99)
	time.Sleep(120 * time.Millisecond)
	done()

	output := buf.String()

	// Verify all expected structured fields are present.
	for _, field := range []string{"query", "rows", "elapsed", "threshold"} {
		if !strings.Contains(output, field) {
			t.Errorf("log output should contain field %q, got: %s", field, output)
		}
	}
}

func TestSlowQueryThreshold(t *testing.T) {
	// Verify the constant value so that the test intent is clear.
	if slowQueryThreshold != 100*time.Millisecond {
		t.Errorf("slowQueryThreshold = %v, want 100ms", slowQueryThreshold)
	}
}
