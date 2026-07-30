"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
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
    <div className="flex h-screen flex-col pb-16">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <div>
          <p className="text-base font-bold text-gray-800">Chat Admin</p>
          <p className="text-xs text-gray-400">Biasanya dibalas dalam beberapa jam</p>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-4 py-3">
        <div className="flex flex-col gap-2">
          {messages.data?.messages.map((m) => (
            <div
              key={m.id}
              className={`max-w-[80%] rounded-lg px-3 py-2 text-sm ${
                m.sender_role === "customer"
                  ? "self-end bg-emerald-600 text-white"
                  : "self-start bg-gray-100 text-gray-800"
              }`}
            >
              {m.text}
            </div>
          ))}
          {messages.data && messages.data.messages.length === 0 && (
            <p className="mt-10 text-center text-sm text-gray-400">
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
        className="flex gap-2 border-t border-gray-100 px-4 py-3"
      >
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Tulis pesan..."
          className="flex-1 rounded-full border border-gray-200 px-4 py-2 text-sm outline-none focus:border-emerald-500"
        />
        <button
          type="submit"
          disabled={send.isPending}
          className="rounded-full bg-emerald-600 px-4 text-sm font-semibold text-white disabled:opacity-50"
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
