package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

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

const (
	maxAgentActionLen   = 50
	maxAgentContextSize = 64 * 1024 // 64 KB
	maxAgentParamsSize  = 64 * 1024
	maxAgentNoteIDs     = 100
)

var allowedAgentActions = map[string]bool{
	"organize_notes":  true,
	"summarize_notes": true,
	"create_note":     true,
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
	if err := validateAgentRequest(req); err != nil {
		return nil, fmt.Errorf("invalid agent request: %w", err)
	}

	// Build the prompt from the action and context using structured delimiters
	// to isolate user-supplied content from the system prompt.
	var promptBuf strings.Builder
	promptBuf.WriteString("<user-request>\n")
	promptBuf.WriteString("Action: ")
	promptBuf.WriteString(sanitizeAgentInput(req.Action))
	promptBuf.WriteString("\n")

	if len(req.NoteIDs) > 0 {
		promptBuf.WriteString("Note IDs: ")
		promptBuf.WriteString(sanitizeAgentInput(fmt.Sprintf("%v", req.NoteIDs)))
		promptBuf.WriteString("\n")
	}

	if contextData, err := json.Marshal(req.Context); err == nil && len(contextData) > 2 {
		promptBuf.WriteString("Context: ")
		promptBuf.WriteString(sanitizeAgentInput(string(contextData)))
		promptBuf.WriteString("\n")
	}

	if params, err := json.Marshal(req.Parameters); err == nil && len(params) > 2 {
		promptBuf.WriteString("Parameters: ")
		promptBuf.WriteString(sanitizeAgentInput(string(params)))
		promptBuf.WriteString("\n")
	}

	promptBuf.WriteString("</user-request>")

	actionPrompt := promptBuf.String()

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

// sanitizeAgentInput escapes angle brackets in user input to prevent
// delimiter-injection attacks. By escaping < and > to HTML entities,
// user content can never create or close the XML-style delimiters
// (<user-request>, </user-request>) used in the prompt template.
func sanitizeAgentInput(input string) string {
	s := strings.ReplaceAll(input, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	return s
}

// validateAgentRequest checks the agent request for valid action and size limits.
func validateAgentRequest(req domain.AIAgentRequest) error {
	if len(req.Action) > maxAgentActionLen || !allowedAgentActions[req.Action] {
		return fmt.Errorf("unsupported action: %q", req.Action)
	}
	if len(req.NoteIDs) > maxAgentNoteIDs {
		return fmt.Errorf("too many note IDs: max %d", maxAgentNoteIDs)
	}
	if ctxData, err := json.Marshal(req.Context); err == nil && len(ctxData) > maxAgentContextSize {
		return fmt.Errorf("context too large: max %d bytes", maxAgentContextSize)
	}
	if params, err := json.Marshal(req.Parameters); err == nil && len(params) > maxAgentParamsSize {
		return fmt.Errorf("parameters too large: max %d bytes", maxAgentParamsSize)
	}
	return nil
}
