"use client";

import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { getCustomerTerms } from "@/lib/api/endpoints";
import { SimpleMarkdown } from "@/lib/simple-markdown";

export default function TermsPage() {
  const router = useRouter();
  const terms = useQuery({ queryKey: ["customer-terms"], queryFn: getCustomerTerms });

  return (
    <div className="pb-6">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Syarat &amp; Ketentuan</p>
      </header>

      <div className="px-4 py-4">
        {terms.isLoading && <p className="text-sm text-gray-400">Memuat...</p>}
        {terms.data && <SimpleMarkdown content={terms.data.content} />}
      </div>
    </div>
  );
}
