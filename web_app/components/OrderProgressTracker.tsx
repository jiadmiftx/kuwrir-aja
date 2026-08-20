import { HugeiconsIcon } from "@hugeicons/react";
import {
  ReceiptTextIcon,
  ChefHatIcon,
  Motorbike01Icon,
  PackageDeliveredIcon,
} from "@hugeicons/core-free-icons";
import { ORDER_PROGRESS_STEPS, orderProgressStepIndex } from "@/lib/order-status";

const ICONS = [ReceiptTextIcon, ChefHatIcon, Motorbike01Icon, PackageDeliveredIcon];

/// Condensed horizontal step tracker, web equivalent of customer_app's
/// _HorizontalTracker — same 4 steps, same "done / active / pending" states.
export function OrderProgressTracker({ status }: { status: string }) {
  const current = orderProgressStepIndex(status);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center">
        {ORDER_PROGRESS_STEPS.map((_, i) => (
          <div key={i} className="flex flex-1 items-center last:flex-none">
            <div
              className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full border-2 transition-colors ${
                i < current
                  ? "border-(--color-accent) bg-(--color-accent) text-(--color-accent-contrast)"
                  : i === current
                    ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)"
                    : "border-(--color-border) bg-(--color-surface-raised) text-(--color-ink-faint)"
              }`}
            >
              <HugeiconsIcon icon={ICONS[i]} size={16} strokeWidth={1.5} />
            </div>
            {i !== ORDER_PROGRESS_STEPS.length - 1 && (
              <div className={`h-0.5 flex-1 ${i < current ? "bg-(--color-accent)" : "bg-(--color-border)"}`} />
            )}
          </div>
        ))}
      </div>
      <div className="flex">
        {ORDER_PROGRESS_STEPS.map((label, i) => (
          <div key={label} className={i === ORDER_PROGRESS_STEPS.length - 1 ? "w-9 shrink-0" : "flex-1"}>
            <p
              className={`text-center text-[10.5px] ${
                i === current
                  ? "font-semibold text-(--color-accent)"
                  : i < current
                    ? "font-medium text-(--color-ink-soft)"
                    : "text-(--color-ink-faint)"
              }`}
            >
              {label}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
