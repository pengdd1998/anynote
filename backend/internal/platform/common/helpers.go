// Package common provides shared helper functions for platform adapters,
// extracted from duplicated patterns across medium, wordpress, wechat,
// xiaohongshu, and zhihu adapters.
package common

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform/chromedputil"
)

// DecryptAuth decrypts encrypted auth data using the master key and
// unmarshals the resulting JSON into target. This is the shared
// decrypt-then-unmarshal pattern used by all platform adapters in their
// Publish, CheckStatus, and RevokeAuth methods.
//
// target must be a pointer to the auth struct specific to the adapter
// (e.g. *mediumAuthData, *wpAuthData).
func DecryptAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte, target interface{}) error {
	plain, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return fmt.Errorf("decrypt auth data: %w", err)
	}
	if err := json.Unmarshal([]byte(plain), target); err != nil {
		return fmt.Errorf("unmarshal auth data: %w", err)
	}
	return nil
}

// DecryptCookieJar decrypts encrypted auth data and unmarshals it into a
// chromedputil.CookieJar. This is the variant used by chromedp-based
// adapters (wechat, xiaohongshu, zhihu) which store browser cookies as
// their auth data.
func DecryptCookieJar(ctx context.Context, encryptedAuth []byte, masterKey []byte) (chromedputil.CookieJar, error) {
	var jar chromedputil.CookieJar
	err := DecryptAuth(ctx, encryptedAuth, masterKey, &jar)
	if err != nil {
		return jar, err
	}
	return jar, nil
}
