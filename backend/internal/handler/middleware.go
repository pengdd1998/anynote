package handler

import (
	"context"
	"log"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const userIDKey contextKey = "user_id"

// Default request body size limits to prevent OOM attacks.
const (
	// DefaultMaxBodyBytes is the global limit applied to all routes (10 MB).
	DefaultMaxBodyBytes int64 = 10 * 1024 * 1024

	// SyncPushMaxBodyBytes is the elevated limit for the sync push endpoint
	// which may contain many encrypted blobs in a single request (50 MB).
	SyncPushMaxBodyBytes int64 = 50 * 1024 * 1024
)

// MaxBodySize returns middleware that wraps request bodies with
// http.MaxBytesReader, rejecting any request whose body exceeds maxBytes.
func MaxBodySize(maxBytes int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
			next.ServeHTTP(w, r)
		})
	}
}

// AuthMiddleware validates JWT tokens and injects user_id into context.
func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	if len(jwtSecret) < 16 {
		log.Fatalf("JWT_SECRET must be at least 16 characters, got %d", len(jwtSecret))
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				writeError(w, r, http.StatusUnauthorized, "missing_authorization", "Authorization header required")
				return
			}

			// Normalize "Bearer" prefix (case-insensitive per RFC 6750).
			tokenStr := authHeader
			if strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
				tokenStr = strings.TrimSpace(authHeader[7:])
			}
			if tokenStr == "" || tokenStr == authHeader {
				writeError(w, r, http.StatusUnauthorized, "invalid_authorization", "Bearer token required")
				return
			}

			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				return []byte(jwtSecret), nil
			}, jwt.WithValidMethods([]string{"HS256"}))

			if err != nil || !token.Valid {
				writeError(w, r, http.StatusUnauthorized, "invalid_token", "Token is invalid or expired")
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				writeError(w, r, http.StatusUnauthorized, "invalid_claims", "Invalid token claims")
				return
			}

			userID, ok := claims["user_id"].(string)
			if !ok {
				writeError(w, r, http.StatusUnauthorized, "invalid_claims", "user_id not found in token")
				return
			}

			// Reject refresh tokens used for API access.
			tokenType, _ := claims["token_type"].(string)
			if tokenType != "access" {
				writeError(w, r, http.StatusUnauthorized, "invalid_token_type", "Access token required")
				return
			}

			ctx := context.WithValue(r.Context(), userIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// getUserID extracts user_id from request context.
func getUserID(ctx context.Context) string {
	if id, ok := ctx.Value(userIDKey).(string); ok {
		return id
	}
	return ""
}
