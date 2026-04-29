// Package fcmadapter provides a shared FCM (Firebase Cloud Messaging) client
// adapter used by both the server and worker main packages. It encapsulates
// the Firebase SDK initialization and adapts the Firebase messaging.Client to
// the service.FCMClient interface.
package fcmadapter

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"

	"github.com/anynote/backend/internal/service"
)

// InitFCMClient initializes the Firebase Cloud Messaging client.
// Returns nil (no error) when credentialsFile is empty, meaning log-only mode.
// Returns an error if the credentials file is specified but invalid.
func InitFCMClient(ctx context.Context, credentialsFile string) (service.FCMClient, error) {
	if credentialsFile == "" {
		return nil, nil
	}

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credentialsFile)) //nolint:staticcheck // intentional: migration to new API not yet planned
	if err != nil {
		return nil, fmt.Errorf("firebase app init: %w", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase messaging client: %w", err)
	}

	return &firebaseFCMClient{client: client}, nil
}

// firebaseFCMClient adapts the Firebase messaging.Client to the service.FCMClient interface.
type firebaseFCMClient struct {
	client *messaging.Client
}

// Send converts the domain FCMMessage to a Firebase messaging.Message and delivers it.
func (f *firebaseFCMClient) Send(ctx context.Context, msg *service.FCMMessage) (string, error) {
	fbMsg := &messaging.Message{
		Token: msg.Token,
		Notification: &messaging.Notification{
			Title: msg.Title,
			Body:  msg.Body,
		},
		Android: &messaging.AndroidConfig{
			Priority: msg.Priority,
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	}

	if len(msg.Data) > 0 {
		fbMsg.Data = msg.Data
		// Enable background content delivery on iOS for data-rich messages.
		fbMsg.APNS.Payload.Aps.ContentAvailable = true
	}

	return f.client.Send(ctx, fbMsg)
}
