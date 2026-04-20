package service

// FCM adapter implementations live in cmd/server/main.go where the Firebase
// SDK dependency is imported. This keeps the service package free of Firebase
// imports, which allows handler/service tests to run without Firebase credentials.
//
// The FCMClient interface is defined in push_service.go. The concrete adapter
// (firebaseFCMClient) is created by cmd/server's initFCMClient() function.
