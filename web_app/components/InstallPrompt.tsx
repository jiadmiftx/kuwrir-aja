"use client";

import { useEffect, useState } from "react";

const DISMISS_KEY = "kuwrir-install-prompt-dismissed";

function isIos() {
  return /iphone|ipad|ipod/i.test(window.navigator.userAgent);
}

function isStandalone() {
  return (
    window.matchMedia("(display-mode: standalone)").matches ||
    (window.navigator as Navigator & { standalone?: boolean }).standalone === true
  );
}

export function InstallPrompt() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    if (localStorage.getItem(DISMISS_KEY)) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-shot check against browser UA/display-mode, not derivable from render
    if (isIos() && !isStandalone()) setShow(true);
  }, []);

  if (!show) return null;

  return (
    <div className="fixed bottom-16 left-0 right-0 z-40 mx-auto max-w-(--shell-width) px-4 pb-3">
      <div className="flex items-start gap-3 rounded-xl bg-gray-900 p-3 text-white shadow-lg">
        <span className="text-xl">📲</span>
        <div className="flex-1 text-xs leading-relaxed">
          <p className="font-semibold">Install Cocourir di iPhone kamu</p>
          <p className="mt-0.5 text-gray-300">
            Ketuk tombol Bagikan <span aria-hidden>⬆️</span> lalu pilih &quot;Add to Home Screen&quot; agar bisa
            menerima notifikasi pesanan.
          </p>
        </div>
        <button
          onClick={() => {
            localStorage.setItem(DISMISS_KEY, "1");
            setShow(false);
          }}
          className="text-gray-400"
        >
          ✕
        </button>
      </div>
    </div>
  );
}
