"use client";

interface Props {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  /** Omit for an info-only dialog (single dismiss button, no onConfirm). */
  onConfirm?: () => void;
  onClose: () => void;
}

/// Styled stand-in for the browser's native confirm()/alert() — same
/// bottom-sheet-on-mobile / centered-card-on-desktop shape as ReviewSheet
/// and ReplacementPickerSheet, so a "are you sure?" doesn't look like it
/// escaped the app's design system.
export function ConfirmDialog({ title, message, confirmLabel, cancelLabel, danger, onConfirm, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-(--color-ink)/45 md:items-center md:p-6" onClick={onClose}>
      <div
        className="mx-auto flex w-full max-w-sm flex-col gap-4 rounded-t-3xl bg-(--color-surface-raised) p-5 md:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div>
          <p className="text-base font-semibold text-(--color-ink)">{title}</p>
          <p className="mt-1.5 whitespace-pre-line text-sm text-(--color-ink-soft)">{message}</p>
        </div>
        <div className="flex gap-2">
          {onConfirm && (
            <button
              onClick={onClose}
              className="flex-1 rounded-full border border-(--color-border) py-2.5 text-sm font-semibold text-(--color-ink-soft)"
            >
              {cancelLabel ?? "Batal"}
            </button>
          )}
          <button
            onClick={() => {
              if (onConfirm) onConfirm();
              onClose();
            }}
            className={`flex-1 rounded-full py-2.5 text-sm font-semibold text-(--color-accent-contrast) ${
              danger ? "bg-(--color-danger)" : "bg-(--color-accent)"
            }`}
          >
            {confirmLabel ?? "OK"}
          </button>
        </div>
      </div>
    </div>
  );
}
