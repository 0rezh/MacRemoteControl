"use client";

import { useEffect, useRef, useState, type PointerEvent, type ReactNode } from "react";

type Props<Action> = {
  action: Action;
  label: string;
  onAction: (action: Action) => void;
  /** Intervalle de répétition (ms) quand on garde le doigt appuyé. */
  repeat?: number;
  disabled?: boolean;
  className?: string;
  children: ReactNode;
};

const REPEAT_DELAY = 380;

/**
 * Bouton déclenché à l'appui (pointerdown, pas au relâchement) pour être réactif,
 * avec répétition optionnelle tant qu'on reste appuyé.
 */
export function HoldButton<Action>({ action, label, onAction, repeat, disabled, className, children }: Props<Action>) {
  const [pressed, setPressed] = useState(false);
  const timers = useRef<{ delay?: number; interval?: number }>({});

  const stop = () => {
    window.clearTimeout(timers.current.delay);
    window.clearInterval(timers.current.interval);
    setPressed(false);
  };

  useEffect(() => stop, []);

  const start = (event: PointerEvent<HTMLButtonElement>) => {
    if (disabled || event.button !== 0) return;
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    setPressed(true);
    onAction(action);
    if (repeat) {
      timers.current.delay = window.setTimeout(() => {
        timers.current.interval = window.setInterval(() => onAction(action), repeat);
      }, REPEAT_DELAY);
    }
  };

  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      disabled={disabled}
      data-pressed={pressed || undefined}
      className={className}
      onPointerDown={start}
      onPointerUp={stop}
      onPointerCancel={stop}
      onLostPointerCapture={stop}
      onContextMenu={(event) => event.preventDefault()}
      onClick={(event) => {
        if (event.detail === 0 && !disabled) onAction(action);
      }}
    >
      {children}
    </button>
  );
}
