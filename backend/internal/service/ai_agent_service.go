package service

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/anynote/backend/internal/domain"
)

// AIAgentService handles autonomous AI agent actions.
type AIAgentService interface {
	ExecuteAction(ctx context.Context, userID string, req domain.AIAgentRequest) (*domain.AIAgentResponse, error)
}

type aiAgentService struct {
	aiProxy AIProxyService
}

// NewAIAgentService creates a new AIAgentService.
func NewAIAgentService(aiProxy AIProxyService) AIAgentService {
	return &aiAgentService{
		aiProxy: aiProxy,
	}
}

// toolDefinitions describes the available agent tools.
const toolDefinitions = `You are an AI agent assistant for a note-taking app. You can perform the following actions:

1. organize_notes: Suggest tags, categories, or groupings for the given notes.
2. summarize_notes: Generate a concise summary of the given notes.
3. create_note: Draft a new note based on the user's description.

Always respond in JSON format with:
- "action": the action you performed
- "result": the action result (object)
- "message": a brief human-readable summary

For organize_notes, include in result: {tags: [...], categories: [...]}
For summarize_notes, include in result: {summary: "..."}
For create_note, include in result: {title: "...", content: "..."}
`

func (s *aiAgentService) ExecuteAction(ctx context.Context, userID string, req domain.AIAgentRequest) (*domain.AIAgentResponse, error) {
	// Build the prompt from the action and context.
	actionPrompt := fmt.Sprintf("Action: %s\n", req.Action)

	if len(req.NoteIDs) > 0 {
		actionPrompt += fmt.Sprintf("Note IDs: %v\n", req.NoteIDs)
	}

	if contextData, err := json.Marshal(req.Context); err == nil && len(contextData) > 2 {
		actionPrompt += fmt.Sprintf("Context: %s\n", string(contextData))
	}

	if params, err := json.Marshal(req.Parameters); err == nil && len(params) > 2 {
		actionPrompt += fmt.Sprintf("Parameters: %s\n", string(params))
	}

	// Route through the existing AI proxy.
	proxyReq := domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "system", Content: toolDefinitions},
			{Role: "user", Content: actionPrompt},
		},
		Stream: false,
	}

	chunkCh, err := s.aiProxy.Proxy(ctx, userID, proxyReq)
	if err != nil {
		return &domain.AIAgentResponse{
			Action:  req.Action,
			Status:  "failed",
			Message: err.Error(),
		}, nil
	}

	// Collect the full response.
	var fullContent string
	for chunk := range chunkCh {
		if chunk.Error != "" {
			return &domain.AIAgentResponse{
				Action:  req.Action,
				Status:  "failed",
				Message: chunk.Error,
			}, nil
		}
		fullContent += chunk.Content
		if chunk.Done {
			break
		}
	}

	// Parse the LLM response as JSON.
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(fullContent), &result); err != nil {
		// If not valid JSON, wrap the raw content.
		result = map[string]interface{}{
			"raw": fullContent,
		}
	}

	return &domain.AIAgentResponse{
		Action: req.Action,
		Status: "completed",
		Result: result,
	}, nil
}
