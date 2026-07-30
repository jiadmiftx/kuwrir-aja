"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { updateMe } from "@/lib/api/endpoints";
import { useAuthStore } from "@/lib/stores/auth";
import { ApiError } from "@/lib/api/client";

function EditProfileContent() {
  const router = useRouter();
  const { user, updateUser } = useAuthStore();
  const [name, setName] = useState(user?.name ?? "");
  const [email, setEmail] = useState(user?.email ?? "");
  const [error, setError] = useState("");

  const save = useMutation({
    mutationFn: () => updateMe({ name, email }),
    onSuccess: (data) => {
      updateUser(data.user);
      router.replace("/profile");
    },
    onError: (err) => setError(err instanceof ApiError ? err.message : "Gagal menyimpan profil"),
  });

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Edit Profil</p>
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          save.mutate();
        }}
        className="mx-4 mt-4 flex max-w-2xl flex-col gap-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4 md:mx-auto md:p-5"
      >
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-(--color-ink-soft)">Nama Lengkap</span>
          <input
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-(--color-ink-soft)">Email</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-(--color-ink-soft)">Nomor HP</span>
          <input
            disabled
            value={user?.phone ?? ""}
            className="rounded-xl border border-(--color-border) bg-(--color-surface) px-3.5 py-2.5 text-sm text-(--color-ink-faint)"
          />
        </label>
        {error && <p className="text-sm text-(--color-danger)">{error}</p>}
        <button
          type="submit"
          disabled={save.isPending || !name}
          className="mt-2 rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
        >
          {save.isPending ? "Menyimpan..." : "Simpan"}
        </button>
      </form>
    </div>
  );
}

export default function EditProfilePage() {
  return (
    <AuthGuard>
      <EditProfileContent />
    </AuthGuard>
  );
}
