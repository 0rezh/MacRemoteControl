"use client";

import { useEffect, useRef, useState, type PointerEvent } from "react";
import type { PointerMessage } from "@/lib/useRemote";

type Props = {
  send: (message: PointerMessage) => boolean;
  onFeedback: () => void;
  disabled?: boolean;
};

/** Distance (px) au-delà de laquelle un toucher n'est plus un clic. */
const TAP_SLOP = 10;
/** Durée max (ms) d'un toucher pour compter comme un clic. */
const TAP_MAX_MS = 280;
/** Gain du curseur : lent = précis, rapide = traverse l'écran. */
const BASE_GAIN = 1.5;
const ACCELERATION = 1.6;
const MAX_ACCELERATION = 3.2;
const SCROLL_GAIN = 1.6;

type TrackedPointer = { x: number; y: number; t: number };

/**
 * Trackpad façon MacBook :
 * 1 doigt glisse = déplacer · toucher = clic · 2 doigts glissent = défiler · toucher à 2 doigts = clic droit.
 */
export function Trackpad({ send, onFeedback, disabled }: Props) {
  const surfaceRef = useRef<HTMLDivElement>(null);
  const pointers = useRef(new Map<number, TrackedPointer>());
  const gesture = useRef({ maxPointers: 0, travel: 0, startTime: 0 });
  const pending = useRef({ dx: 0, dy: 0, sx: 0, sy: 0, frame: 0 });

  useEffect(() => () => cancelAnimationFrame(pending.current.frame), []);

  const flush = () => {
    const p = pending.current;
    p.frame = 0;
    if ((p.dx || p.dy) && send({ type: "move", dx: round(p.dx), dy: round(p.dy) })) {
      p.dx = 0;
      p.dy = 0;
    }
    const sx = Math.trunc(p.sx);
    const sy = Math.trunc(p.sy);
    if ((sx || sy) && send({ type: "scroll", dx: sx, dy: sy })) {
      p.sx -= sx;
      p.sy -= sy;
    }
    if (p.dx || p.dy || Math.trunc(p.sx) || Math.trunc(p.sy)) schedule();
  };

  const schedule = () => {
    if (!pending.current.frame) pending.current.frame = requestAnimationFrame(flush);
  };

  /** Lueur sous le(s) doigt(s), mise à jour sans re-render React. */
  const updateGlow = () => {
    const surface = surfaceRef.current;
    if (!surface) return;
    const points = [...pointers.current.values()];
    if (points.length === 0) {
      delete surface.dataset.active;
      return;
    }
    const rect = surface.getBoundingClientRect();
    const x = points.reduce((sum, p) => sum + p.x, 0) / points.length - rect.left;
    const y = points.reduce((sum, p) => sum + p.y, 0) / points.length - rect.top;
    surface.style.setProperty("--x", `${x}px`);
    surface.style.setProperty("--y", `${y}px`);
    surface.dataset.active = points.length > 1 ? "multi" : "single";
  };

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (disabled) return;
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    if (pointers.current.size === 0) {
      gesture.current = { maxPointers: 0, travel: 0, startTime: event.timeStamp };
    }
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY, t: event.timeStamp });
    gesture.current.maxPointers = Math.max(gesture.current.maxPointers, pointers.current.size);
    updateGlow();
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const previous = pointers.current.get(event.pointerId);
    if (!previous) return;
    const dx = event.clientX - previous.x;
    const dy = event.clientY - previous.y;
    const dt = Math.max(event.timeStamp - previous.t, 1);
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY, t: event.timeStamp });

    const g = gesture.current;
    g.travel += Math.hypot(dx, dy);
    const count = pointers.current.size;

    if (g.maxPointers === 1) {
      const speed = Math.hypot(dx, dy) / dt;
      const gain = BASE_GAIN * Math.min(1 + speed * ACCELERATION, MAX_ACCELERATION);
      pending.current.dx += dx * gain;
      pending.current.dy += dy * gain;
    } else if (count >= 2) {
      pending.current.sx += (dx * SCROLL_GAIN) / count;
      pending.current.sy += (dy * SCROLL_GAIN) / count;
    }
    schedule();
    updateGlow();
  };

  const onPointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    if (!pointers.current.delete(event.pointerId)) return;
    updateGlow();
    if (pointers.current.size > 0) return;

    const g = gesture.current;
    const isTap = event.type === "pointerup" && g.travel < TAP_SLOP && event.timeStamp - g.startTime < TAP_MAX_MS;
    if (isTap && !disabled) {
      onFeedback();
      send({ type: "click", button: g.maxPointers >= 2 ? "right" : "left" });
    }
  };

  return (
    <div className="trackpad">
      <div
        ref={surfaceRef}
        className="trackpad__surface"
        aria-label="Trackpad : glisser pour déplacer, toucher pour cliquer, deux doigts pour défiler ou clic droit"
        role="application"
        data-disabled={disabled || undefined}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerEnd}
        onPointerCancel={onPointerEnd}
        onContextMenu={(event) => event.preventDefault()}
      >
        <ul className="trackpad__hints" aria-hidden>
          <li><b>Un doigt</b> Déplacer · Toucher pour cliquer</li>
          <li><b>Deux doigts</b> Défiler · Toucher pour le clic droit</li>
        </ul>
      </div>

      <div className="trackpad__buttons">
        <MouseKey button="left" label="Clic" send={send} onFeedback={onFeedback} disabled={disabled} />
        <MouseKey button="right" label="Clic droit" send={send} onFeedback={onFeedback} disabled={disabled} />
      </div>
    </div>
  );
}

/**
 * Bouton physique : appuyé = bouton enfoncé côté Mac.
 * Garder « Clic » enfoncé avec le pouce tout en glissant sur le trackpad = glisser-déposer.
 */
function MouseKey({
  button,
  label,
  send,
  onFeedback,
  disabled,
}: {
  button: "left" | "right";
  label: string;
  send: Props["send"];
  onFeedback: () => void;
  disabled?: boolean;
}) {
  const [pressed, setPressed] = useState(false);
  const pressedRef = useRef(false);

  const release = () => {
    if (!pressedRef.current) return;
    pressedRef.current = false;
    setPressed(false);
    send({ type: "button", button, down: false });
  };

  useEffect(() => release, []);

  return (
    <button
      type="button"
      className="keycap keycap--text"
      data-pressed={pressed || undefined}
      disabled={disabled}
      onPointerDown={(event) => {
        if (disabled || event.button !== 0) return;
        event.preventDefault();
        event.currentTarget.setPointerCapture(event.pointerId);
        pressedRef.current = true;
        setPressed(true);
        onFeedback();
        send({ type: "button", button, down: true });
      }}
      onPointerUp={release}
      onPointerCancel={release}
      onLostPointerCapture={release}
      onContextMenu={(event) => event.preventDefault()}
      onClick={(event) => {
        if (event.detail === 0 && !disabled) send({ type: "click", button });
      }}
    >
      <span className="keycap__label">{label}</span>
    </button>
  );
}

function round(value: number) {
  return Math.round(value * 100) / 100;
}
