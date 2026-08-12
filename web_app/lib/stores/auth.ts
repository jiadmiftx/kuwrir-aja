import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { User } from "@/lib/api/types";

interface AuthState {
  token: string | null;
  refreshToken: string | null;
  user: User | null;
  // Zustand's persist middleware reads localStorage asynchronously, so the
  // very first client render always sees the pre-hydration defaults (token:
  // null) even when a valid session is saved. Without this flag, AuthGuard
  // can't tell "genuinely logged out" apart from "hasn't finished loading
  // the saved session yet" and redirects to /login on that false read.
  hasHydrated: boolean;
  setAuth: (token: string, refreshToken: string, user: User) => void;
  updateUser: (user: User) => void;
  clear: () => void;
  setHasHydrated: (v: boolean) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      refreshToken: null,
      user: null,
      hasHydrated: false,
      setAuth: (token, refreshToken, user) => set({ token, refreshToken, user }),
      updateUser: (user) => set({ user }),
      clear: () => set({ token: null, refreshToken: null, user: null }),
      setHasHydrated: (v) => set({ hasHydrated: v }),
    }),
    {
      name: "kuwrir-auth",
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);
      },
      partialize: (state) => ({
        token: state.token,
        refreshToken: state.refreshToken,
        user: state.user,
      }),
    }
  )
);
