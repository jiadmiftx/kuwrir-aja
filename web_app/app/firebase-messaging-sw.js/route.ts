import { firebaseConfig } from "@/lib/firebase/config";

// Served at the URL path /firebase-messaging-sw.js (this folder's literal
// name is the route segment) so the service worker's default scope covers
// the whole origin — Firebase Messaging requires that exact top-level path,
// it can't live under /sw/ or similar. Generated dynamically (rather than a
// static public/ file) so the config can come from runtime env, not just
// whatever was baked in at Docker build time.
export async function GET() {
  const body = `
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp(${JSON.stringify(firebaseConfig)});

const messaging = firebase.messaging();

// Foreground messages are handled in lib/firebase/messaging.ts instead —
// this only fires when the tab/PWA isn't focused.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || "Cocourir";
  const options = {
    body: payload.notification?.body || "",
    icon: "/icons/icon-192.png",
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const orderId = event.notification.data?.order_id;
  const url = orderId ? \`/orders/\${orderId}\` : "/orders";
  event.waitUntil(clients.openWindow(url));
});
`.trim();

  return new Response(body, {
    headers: { "Content-Type": "application/javascript; charset=utf-8" },
  });
}
