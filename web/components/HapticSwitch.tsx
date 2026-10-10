"use client";

// `switch` n'est pas un attribut connu de React ni de TypeScript : on le pose à la main.
const markAsSwitch = (input: HTMLInputElement | null) => input?.setAttribute("switch", "");

/**
 * Interrupteur iOS invisible qui recouvre la touche : c'est lui que le doigt touche, et iOS joue son
 * tick haptique quand il bascule, au relâchement. Depuis iOS 26.5, seul un vrai toucher fait vibrer :
 * le basculer en JS ne marche plus. Sur Android et sur ordinateur, il reste inerte.
 * À placer dans un parent en position relative.
 */
export function HapticSwitch({ disabled }: { disabled?: boolean }) {
  return (
    <input
      ref={markAsSwitch}
      type="checkbox"
      className="haptic-switch"
      tabIndex={-1}
      aria-hidden
      disabled={disabled}
      // Au relâchement, iOS envoie un clic de detail 0, que la touche prendrait pour le clavier : il ne doit pas remonter.
      onClick={(event) => event.stopPropagation()}
    />
  );
}
