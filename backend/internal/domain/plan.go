// Package domain defines shared domain types for the AnyNote backend.
package domain

// Plan represents a user subscription tier.
type Plan string

const (
	PlanFree     Plan = "free"
	PlanPro      Plan = "pro"
	PlanLifetime Plan = "lifetime"
)

// ValidPlans is the set of recognized plan values.
var ValidPlans = map[Plan]bool{
	PlanFree:     true,
	PlanPro:      true,
	PlanLifetime: true,
}

// PlanLimits describes the resource limits for a subscription plan.
type PlanLimits struct {
	MaxNotes        int   `json:"max_notes"`
	MaxCollections  int   `json:"max_collections"`
	AIDailyQuota    int   `json:"ai_daily_quota"`
	MaxStorageBytes int64 `json:"max_storage_bytes"`
	MaxDevices      int   `json:"max_devices"`
	CanCollaborate  bool  `json:"can_collaborate"`
	CanPublish      bool  `json:"can_publish"`
}

// PlanLimitsMap holds the limits for every plan tier.
var PlanLimitsMap = map[Plan]PlanLimits{
	PlanFree: {
		MaxNotes:        500,
		MaxCollections:  20,
		AIDailyQuota:    50,
		MaxStorageBytes: 100 * 1024 * 1024, // 100 MB
		MaxDevices:      2,
		CanCollaborate:  false,
		CanPublish:      true,
	},
	PlanPro: {
		MaxNotes:        10_000,
		MaxCollections:  100,
		AIDailyQuota:    500,
		MaxStorageBytes: 5 * 1024 * 1024 * 1024, // 5 GB
		MaxDevices:      5,
		CanCollaborate:  true,
		CanPublish:      true,
	},
	PlanLifetime: {
		MaxNotes:        -1, // unlimited
		MaxCollections:  -1,
		AIDailyQuota:    -1,
		MaxStorageBytes: -1, // unlimited
		MaxDevices:      -1,
		CanCollaborate:  true,
		CanPublish:      true,
	},
}

// GetPlanLimits returns the limits for the given plan, defaulting to the free
// tier limits when the plan is unrecognized.
func GetPlanLimits(p Plan) PlanLimits {
	if limits, ok := PlanLimitsMap[p]; ok {
		return limits
	}
	return PlanLimitsMap[PlanFree]
}

// PlanInfo is the response payload for GET /api/v1/plan.
type PlanInfo struct {
	Plan         Plan       `json:"plan"`
	Limits       PlanLimits `json:"limits"`
	AIDailyUsed  int        `json:"ai_daily_used"`
	StorageBytes int64      `json:"storage_bytes"`
	NoteCount    int        `json:"note_count"`
}

// UpgradePlanRequest is the payload for POST /api/v1/plan/upgrade.
type UpgradePlanRequest struct {
	Plan        Plan   `json:"plan"`
	PaymentRef  string `json:"payment_ref,omitempty"`
}

// ── Public Profile ──────────────────────────────────────

// PublicProfile holds the public-facing profile data for a user.
type PublicProfile struct {
	Username      string `json:"username"`
	DisplayName   string `json:"display_name"`
	Bio           string `json:"bio"`
	Plan          string `json:"plan"`
	PublicEnabled bool   `json:"public_profile_enabled"`
}
