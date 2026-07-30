// Web app registration for the same Firebase project the 3 Flutter apps
// use (projectId "kuwrir-3495d", see customer_app/lib/firebase_options.dart)
// doesn't exist yet — these must be filled in after adding a Web app to
// that project in the Firebase console (Project settings → Add app → Web)
// and generating a Cloud Messaging Web Push certificate (VAPID key) under
// Project settings → Cloud Messaging → Web configuration. All of these are
// public, non-secret values (safe to bake into the client bundle / a
// public route), unlike a service account key.
export const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? "",
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? "",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? "kuwrir-3495d",
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET ?? "",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID ?? "",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID ?? "",
};

export const firebaseVapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY ?? "";

export const isFirebaseConfigured = Boolean(
  firebaseConfig.apiKey && firebaseConfig.appId && firebaseVapidKey
);
