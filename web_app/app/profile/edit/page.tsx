"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
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
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Edit Profil</p>
      </header>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          save.mutate();
        }}
        className="flex flex-col gap-3 px-4 py-4"
      >
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Nama Lengkap</span>
          <input
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Email</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Nomor HP</span>
          <input
            disabled
            value={user?.phone ?? ""}
            className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-400"
          />
        </label>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={save.isPending || !name}
          className="mt-2 rounded-full bg-emerald-600 py-3 text-sm font-semibold text-white disabled:opacity-50"
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
