"use client";

import { initializeApp, getApps, getApp } from "firebase/app";
import { getMessaging, getToken, isSupported, onMessage } from "firebase/messaging";
import { firebaseConfig, firebaseVapidKey, isFirebaseConfigured } from "@/lib/firebase/config";

function getFirebaseApp() {
  return getApps().length ? getApp() : initializeApp(firebaseConfig);
}

export type PushPermissionResult = "granted" | "denied" | "unsupported" | "unconfigured";

// Requests notification permission and returns the FCM registration token,
// or null if permission was denied / the platform can't support it (Safari
// outside an installed PWA, browsers without the Push API, etc.) — caller
// decides what to do with null (keep relying on polling, as every Flutter
// app already does as a fallback).
export async function requestPushToken(): Promise<{ token: string | null; result: PushPermissionResult }> {
  if (!isFirebaseConfigured) return { token: null, result: "unconfigured" };
  if (typeof window === "undefined" || !("serviceWorker" in navigator)) {
    return { token: null, result: "unsupported" };
  }
  if (!(await isSupported())) return { token: null, result: "unsupported" };

  const permission = await Notification.requestPermission();
  if (permission !== "granted") return { token: null, result: "denied" };

  const registration = await navigator.serviceWorker.register("/firebase-messaging-sw.js");
  const app = getFirebaseApp();
  const messaging = getMessaging(app);
  const token = await getToken(messaging, {
    vapidKey: firebaseVapidKey,
    serviceWorkerRegistration: registration,
  });
  return { token, result: "granted" };
}

// Foreground messages (tab focused) don't trigger the service worker's
// background handler — this is the only place they're caught, so the
// caller decides how to surface them (toast, refetch a query, etc.).
export async function subscribeForegroundMessages(onMessageReceived: (payload: unknown) => void) {
  if (!isFirebaseConfigured || typeof window === "undefined") return () => {};
  if (!(await isSupported())) return () => {};
  const messaging = getMessaging(getFirebaseApp());
  return onMessage(messaging, onMessageReceived);
}
