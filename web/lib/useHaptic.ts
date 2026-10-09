"use client";

import { useCallback } from "react";

/**
 * Petit retour haptique à chaque appui, pour sentir la commande sans regarder l'écran.
 * Android : navigator.vibrate. iOS 18+ : basculer un interrupteur (<input switch>) déclenche le moteur
 * haptique ; il est créé à chaque appui, caché dans <head>, puis retiré.
 */
export function useHaptic() {
  const trigger = useCallback(() => {
    if (typeof navigator.vibrate === "function") {
      navigator.vibrate(12);
      return;
    }
    const label = document.createElement("label");
    label.ariaHidden = "true";
    label.style.display = "none";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.setAttribute("switch", "");
    label.appendChild(input);
    document.head.appendChild(label);
    label.click();
    label.remove();
  }, []);

  return { trigger };
}
