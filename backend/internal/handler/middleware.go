package handler

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const userIDKey contextKey = "user_id"

// AuthMiddleware validates JWT tokens and injects user_id into context.
func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				writeError(w, http.StatusUnauthorized, "missing_authorization", "Authorization header required")
				return
			}

			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			if tokenStr == authHeader {
				writeError(w, http.StatusUnauthorized, "invalid_authorization", "Bearer token required")
				return
			}

			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, jwt.ErrSignatureInvalid
				}
				return []byte(jwtSecret), nil
			})

			if err != nil || !token.Valid {
				writeError(w, http.StatusUnauthorized, "invalid_token", "Token is invalid or expired")
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				writeError(w, http.StatusUnauthorized, "invalid_claims", "Invalid token claims")
				return
			}

			userID, ok := claims["user_id"].(string)
			if !ok {
				writeError(w, http.StatusUnauthorized, "invalid_claims", "user_id not found in token")
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
