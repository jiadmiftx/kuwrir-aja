"use client";

import { useEffect, useState } from "react";
import { HugeiconsIcon } from "@hugeicons/react";
import { Download01Icon, Share08Icon, Cancel01Icon } from "@hugeicons/core-free-icons";

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
    <div className="fixed bottom-16 left-0 right-0 z-40 mx-auto max-w-lg px-4 pb-3 md:bottom-4">
      <div className="flex items-start gap-3 rounded-2xl bg-(--color-ink) p-3.5 text-(--color-accent-contrast) shadow-lg">
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/10">
          <HugeiconsIcon icon={Download01Icon} size={16} strokeWidth={1.5} />
        </span>
        <div className="flex-1 text-xs leading-relaxed">
          <p className="font-semibold">Install Cocourir di iPhone kamu</p>
          <p className="mt-0.5 flex flex-wrap items-center gap-1 text-white/70">
            Ketuk tombol Bagikan
            <HugeiconsIcon icon={Share08Icon} size={13} strokeWidth={1.5} className="inline" />
            lalu pilih &quot;Add to Home Screen&quot; agar bisa menerima notifikasi pesanan.
          </p>
        </div>
        <button
          onClick={() => {
            localStorage.setItem(DISMISS_KEY, "1");
            setShow(false);
          }}
          className="text-white/50"
          aria-label="Tutup"
        >
          <HugeiconsIcon icon={Cancel01Icon} size={15} strokeWidth={1.5} />
        </button>
      </div>
    </div>
  );
}
