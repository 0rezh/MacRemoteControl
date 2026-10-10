"use client";

import { useCallback } from "react";

/**
 * Petit retour haptique à chaque appui, pour sentir la commande sans regarder l'écran.
 * Android : navigator.vibrate. iOS n'a pas cette API et ne vibre plus sur commande JS depuis iOS 26.5 :
 * là-bas, c'est le HapticSwitch posé sur chaque touche qui vibre, au relâchement.
 */
export function useHaptic() {
  const trigger = useCallback(() => {
    if (typeof navigator.vibrate === "function") navigator.vibrate(12);
  }, []);

  return { trigger };
}
