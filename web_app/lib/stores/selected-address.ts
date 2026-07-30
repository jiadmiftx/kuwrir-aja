import { create } from "zustand";
import { persist } from "zustand/middleware";

interface SelectedAddressState {
  addressId: string | null;
  setAddressId: (id: string | null) => void;
}

export const useSelectedAddressStore = create<SelectedAddressState>()(
  persist((set) => ({ addressId: null, setAddressId: (addressId) => set({ addressId }) }), {
    name: "kuwrir-selected-address",
  })
);
