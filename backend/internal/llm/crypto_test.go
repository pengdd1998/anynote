package llm

import (
	"bytes"
	"crypto/rand"
	"testing"
)

func TestEncryptDecryptAPIKey(t *testing.T) {
	masterKey := make([]byte, 32)
	if _, err := rand.Read(masterKey); err != nil {
		t.Fatalf("generate master key: %v", err)
	}

	tests := []struct {
		name      string
		plaintext string
	}{
		{"empty", ""},
		{"short", "sk-abc123"},
		{"long", "sk-proj-abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
		{"chinese", "这是一个中文密钥测试"},
		{"special", "sk-!@#$%^&*()_+-=[]{}|;':\",./<>?"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ciphertext, err := EncryptAPIKey(tt.plaintext, masterKey)
			if err != nil {
				t.Fatalf("encrypt: %v", err)
			}

			// Ciphertext should differ from plaintext
			if tt.plaintext != "" && bytes.Equal([]byte(tt.plaintext), ciphertext) {
				t.Error("ciphertext should not equal plaintext")
			}

			// Ciphertext should include nonce (12 bytes) + data + tag (16 bytes)
			if len(ciphertext) < 12+16 {
				t.Errorf("ciphertext too short: %d bytes", len(ciphertext))
			}

			// Decrypt should recover original
			decrypted, err := DecryptAPIKey(ciphertext, masterKey)
			if err != nil {
				t.Fatalf("decrypt: %v", err)
			}

			if decrypted != tt.plaintext {
				t.Errorf("got %q, want %q", decrypted, tt.plaintext)
			}
		})
	}
}

func TestEncryptProducesDifferentCiphertexts(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)
	plaintext := "sk-test-key-12345"

	ct1, _ := EncryptAPIKey(plaintext, masterKey)
	ct2, _ := EncryptAPIKey(plaintext, masterKey)

	if bytes.Equal(ct1, ct2) {
		t.Error("two encryptions of same plaintext should produce different ciphertexts (random nonce)")
	}

	// Both should decrypt correctly
	d1, _ := DecryptAPIKey(ct1, masterKey)
	d2, _ := DecryptAPIKey(ct2, masterKey)

	if d1 != plaintext || d2 != plaintext {
		t.Error("both should decrypt to original plaintext")
	}
}

func TestDecryptWithWrongKey(t *testing.T) {
	key1 := make([]byte, 32)
	key2 := make([]byte, 32)
	rand.Read(key1)
	rand.Read(key2)

	ciphertext, err := EncryptAPIKey("secret-key", key1)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}

	_, err = DecryptAPIKey(ciphertext, key2)
	if err == nil {
		t.Error("decryption with wrong key should fail")
	}
}

func TestDecryptTamperedCiphertext(t *testing.T) {
	key := make([]byte, 32)
	rand.Read(key)

	ciphertext, _ := EncryptAPIKey("secret-key", key)

	// Tamper with ciphertext
	ciphertext[len(ciphertext)-1] ^= 0xFF

	_, err := DecryptAPIKey(ciphertext, key)
	if err == nil {
		t.Error("decryption of tampered ciphertext should fail (AEAD integrity)")
	}
}

// ---------------------------------------------------------------------------
// Error path tests
// ---------------------------------------------------------------------------

func TestEncryptAPIKey_InvalidKeySize(t *testing.T) {
	_, err := EncryptAPIKey("test", []byte("short-key"))
	if err == nil {
		t.Error("expected error for key shorter than 32 bytes")
	}
}

func TestDecryptAPIKey_InvalidKeySize(t *testing.T) {
	_, err := DecryptAPIKey([]byte("some-data-here"), []byte("short"))
	if err == nil {
		t.Error("expected error for key shorter than 32 bytes")
	}
}

func TestDecryptAPIKey_CiphertextTooShort(t *testing.T) {
	key := make([]byte, 32)
	rand.Read(key)

	// Less than nonce size (12 bytes)
	_, err := DecryptAPIKey([]byte("short"), key)
	if err == nil {
		t.Error("expected error for ciphertext shorter than nonce size")
	}
}

func TestDecryptAPIKey_ExactlyNonceSize(t *testing.T) {
	key := make([]byte, 32)
	rand.Read(key)

	// Exactly 12 bytes (nonce) but no actual encrypted data + tag
	ciphertext := make([]byte, 12)
	_, err := DecryptAPIKey(ciphertext, key)
	if err == nil {
		t.Error("expected error for ciphertext with only nonce and no encrypted data")
	}
}
