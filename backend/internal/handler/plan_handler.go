package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// PlanHandler handles plan-related HTTP endpoints.
type PlanHandler struct {
	planSvc  service.PlanService
	quotaSvc service.QuotaService
}

// NewPlanHandler creates a new PlanHandler.
func NewPlanHandler(planSvc service.PlanService, quotaSvc service.QuotaService) *PlanHandler {
	return &PlanHandler{
		planSvc:  planSvc,
		quotaSvc: quotaSvc,
	}
}

// GetPlan returns the current user's plan, limits, and usage.
// GET /api/v1/plan
func (h *PlanHandler) GetPlan(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	info, err := h.planSvc.GetUserPlan(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "plan_error", "Failed to get plan info")
		return
	}

	writeJSON(w, http.StatusOK, info)
}

// UpgradePlan handles plan upgrade requests.
// POST /api/v1/plan/upgrade
func (h *PlanHandler) UpgradePlan(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	defer r.Body.Close()

	var req domain.UpgradePlanRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if !domain.ValidPlans[req.Plan] {
		writeError(w, r, http.StatusBadRequest, "invalid_plan", "Plan must be one of: free, pro, lifetime")
		return
	}

	if err := h.planSvc.UpgradePlan(r.Context(), userID, req.Plan, req.PaymentRef); err != nil {
		if err == service.ErrInvalidPlan {
			writeError(w, r, http.StatusBadRequest, "invalid_plan", err.Error())
			return
		}
		writeError(w, r, http.StatusInternalServerError, "upgrade_error", "Failed to upgrade plan")
		return
	}

	// Return the updated plan info.
	info, err := h.planSvc.GetUserPlan(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "upgraded", "plan": string(req.Plan)})
		return
	}

	writeJSON(w, http.StatusOK, info)
}
