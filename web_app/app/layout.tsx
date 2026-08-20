import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Providers } from "@/lib/providers";
import { TopNav } from "@/components/TopNav";
import { BottomNav } from "@/components/BottomNav";
import { FloatingCartButton } from "@/components/FloatingCartButton";
import { InstallPrompt } from "@/components/InstallPrompt";
import { PushForegroundListener } from "@/components/PushForegroundListener";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Cocourir",
  description: "Pesan makanan & kebutuhan harian, diantar cepat.",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    // "default"/"black" reserve a status-bar strip iOS paints itself in a
    // fixed color that ignores the page — in practice that's what shows up
    // as a flat black bar on standalone launch. "black-translucent" lets
    // our own background (plus the safe-area-inset-top padding in
    // globals.css) show through instead.
    statusBarStyle: "black-translucent",
    title: "Cocourir",
  },
  icons: {
    icon: [{ url: "/favicon-32.png", sizes: "32x32", type: "image/png" }],
    apple: [{ url: "/icons/icon-180.png", sizes: "180x180", type: "image/png" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#005734",
  width: "device-width",
  initialScale: 1,
  // Without viewport-fit=cover, iOS standalone (added-to-homescreen) mode
  // doesn't extend page content into the notch/home-indicator safe areas
  // at all — it just paints those strips solid black by default, regardless
  // of body background. "cover" lets our own background show through
  // instead; the env(safe-area-inset-*) padding below then keeps real
  // content (nav bars, etc.) out of the notch/indicator itself.
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="id"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full">
        <Providers>
          <TopNav />
          <div className="app-content min-h-screen">{children}</div>
          <BottomNav />
          <FloatingCartButton />
          <InstallPrompt />
          <PushForegroundListener />
        </Providers>
      </body>
    </html>
  );
}
