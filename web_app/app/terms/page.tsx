"use client";

import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon } from "@hugeicons/core-free-icons";
import { getCustomerTerms } from "@/lib/api/endpoints";
import { SimpleMarkdown } from "@/lib/simple-markdown";

export default function TermsPage() {
  const router = useRouter();
  const terms = useQuery({ queryKey: ["customer-terms"], queryFn: getCustomerTerms });

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Syarat &amp; Ketentuan</p>
      </div>

      <div className="mx-auto max-w-2xl px-4 py-4 text-(--color-ink-soft) md:px-0">
        {terms.isLoading && <p className="text-sm text-(--color-ink-faint)">Memuat...</p>}
        {terms.data && <SimpleMarkdown content={terms.data.content} />}
      </div>
    </div>
  );
}
