"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, CustomerService01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getSupportMessages, sendSupportMessage } from "@/lib/api/endpoints";

function SupportContent() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [text, setText] = useState("");

  const messages = useQuery({
    queryKey: ["support-messages"],
    queryFn: getSupportMessages,
    refetchInterval: 15_000,
  });

  const send = useMutation({
    mutationFn: () => sendSupportMessage(text),
    onSuccess: () => {
      setText("");
      queryClient.invalidateQueries({ queryKey: ["support-messages"] });
    },
  });

  return (
    <div className="flex h-[calc(100dvh-4rem)] flex-col md:mx-auto md:h-[75vh] md:max-w-2xl md:mt-8 md:mb-8 md:rounded-2xl md:border md:border-(--color-border) md:overflow-hidden">
      <div className="flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:px-5">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <HugeiconsIcon icon={CustomerService01Icon} size={20} strokeWidth={1.5} className="hidden text-(--color-ink-faint) md:block" />
        <div>
          <p className="text-base font-semibold text-(--color-ink)">Chat Admin</p>
          <p className="text-xs text-(--color-ink-faint)">Biasanya dibalas dalam beberapa jam</p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-3">
        <div className="flex flex-col gap-2">
          {messages.data?.messages.map((m) => (
            <div
              key={m.id}
              className={`max-w-[80%] rounded-2xl px-3.5 py-2 text-sm ${
                m.sender_role === "customer"
                  ? "self-end bg-(--color-accent) text-(--color-accent-contrast)"
                  : "self-start bg-(--color-border-soft) text-(--color-ink)"
              }`}
            >
              {m.text}
            </div>
          ))}
          {messages.data && messages.data.messages.length === 0 && (
            <p className="mt-10 text-center text-sm text-(--color-ink-faint)">
              Ada pertanyaan atau kendala? Kirim pesan ke tim kami di bawah.
            </p>
          )}
        </div>
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (text.trim()) send.mutate();
        }}
        className="flex gap-2 border-t border-(--color-border) bg-(--color-surface-raised) px-4 py-3"
      >
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Tulis pesan..."
          className="flex-1 rounded-full border border-(--color-border) px-4 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
        />
        <button
          type="submit"
          disabled={send.isPending}
          className="rounded-full bg-(--color-accent) px-4 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-50"
        >
          Kirim
        </button>
      </form>
    </div>
  );
}

export default function SupportPage() {
  return (
    <AuthGuard>
      <SupportContent />
    </AuthGuard>
  );
}
