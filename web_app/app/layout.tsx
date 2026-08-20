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
    statusBarStyle: "default",
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
          <div className="min-h-screen pb-20 md:pb-8">{children}</div>
          <BottomNav />
          <FloatingCartButton />
          <InstallPrompt />
          <PushForegroundListener />
        </Providers>
      </body>
    </html>
  );
}
