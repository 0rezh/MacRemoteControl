"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { CircleX, Keyboard } from "lucide-react";
import { HapticSwitch } from "@/components/HapticSwitch";
import { HoldButton } from "@/components/HoldButton";
import type { KeyboardMessage, KeyModifier } from "@/lib/useRemote";

type Props = {
  send: (message: KeyboardMessage) => boolean;
  onFeedback: () => void;
  disabled?: boolean;
};

/** Comme la touche majuscule d'iOS : un appui = pour la prochaine touche, deux appuis = verrouillé. */
type ModifierState = "off" | "armed" | "locked";
type Modifiers = Record<KeyModifier, ModifierState>;

const MODIFIERS: { id: KeyModifier; symbol: string; legend: string; label: string }[] = [
  { id: "shift", symbol: "⇧", legend: "shift", label: "Majuscule" },
  { id: "control", symbol: "⌃", legend: "control", label: "Contrôle" },
  { id: "option", symbol: "⌥", legend: "option", label: "Option" },
  { id: "command", symbol: "⌘", legend: "command", label: "Commande" },
];
/** Ordre des symboles dans les menus macOS (⌃ ⌥ ⇧ ⌘). */
const SYMBOL_ORDER: KeyModifier[] = ["control", "option", "shift", "command"];
const SYMBOLS: Record<KeyModifier, string> = { shift: "⇧", control: "⌃", option: "⌥", command: "⌘" };
const KEY_SYMBOLS: Record<string, string> = { tab: "⇥", delete: "⌫", return: "↩", " ": "Espace" };

const ALL_OFF: Modifiers = { shift: "off", control: "off", option: "off", command: "off" };

/**
 * Caractères invisibles (espaces de largeur nulle) laissés dans le champ :
 * sans eux, iOS ne signale rien quand on appuie sur ⌫ dans un champ vide.
 */
const ZERO_WIDTH_SPACE = String.fromCharCode(0x200b);
const SENTINEL = ZERO_WIDTH_SPACE.repeat(4);
const DOUBLE_TAP_MS = 350;
const ECHO_LENGTH = 500;
const HUD_DURATION_MS = 1100;

/**
 * Zone de saisie : la toucher ouvre le clavier de l'iPhone, et ce qu'on tape part sur le Mac.
 * La zone affiche le texte tapé ; les raccourcis (⌘H…) s'affichent un instant dans une bulle.
 * Dessous, tab et les modificateurs du clavier Mac (⇧ ⌃ ⌥ ⌘).
 */
export function TypingPad({ send, onFeedback, disabled }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const echoRef = useRef<HTMLDivElement>(null);
  const [focused, setFocused] = useState(false);
  const focusedRef = useRef(false);
  const composing = useRef(false);

  const [modifiers, setModifiers] = useState<Modifiers>(ALL_OFF);
  const modifiersRef = useRef<Modifiers>(ALL_OFF);
  const lastTap = useRef<{ id: KeyModifier; time: number } | null>(null);

  /** Aperçu du texte tapé (local : l'effacer n'efface rien sur le Mac). */
  const [echo, setEcho] = useState("");
  const [hud, setHud] = useState<{ label: string; id: number } | null>(null);
  const hudTimer = useRef<number | undefined>(undefined);

  const lockedOf = (state: Modifiers) => SYMBOL_ORDER.filter((id) => state[id] === "locked");
  const activeOf = (state: Modifiers) => SYMBOL_ORDER.filter((id) => state[id] !== "off");

  const updateModifiers = (next: Modifiers) => {
    const wasLocked = lockedOf(modifiersRef.current).join();
    modifiersRef.current = next;
    setModifiers(next);
    if (lockedOf(next).join() !== wasLocked) send({ type: "modifiers", held: lockedOf(next) });
  };

  const sendRef = useRef(send);
  sendRef.current = send;
  useEffect(
    () => () => {
      window.clearTimeout(hudTimer.current);
      if (lockedOf(modifiersRef.current).length) sendRef.current({ type: "modifiers", held: [] });
    },
    [],
  );

  useLayoutEffect(() => {
    const element = echoRef.current;
    if (element) element.scrollTop = element.scrollHeight;
  }, [echo, focused]);

  const showHud = (label: string) => {
    window.clearTimeout(hudTimer.current);
    setHud({ label, id: Date.now() });
    hudTimer.current = window.setTimeout(() => setHud(null), HUD_DURATION_MS);
  };

  const appendText = (text: string) => setEcho((current) => Array.from(current + text).slice(-ECHO_LENGTH).join(""));
  const eraseLast = () => setEcho((current) => Array.from(current).slice(0, -1).join(""));

  /** Une touche avec les modificateurs actifs ; les modificateurs « armés » se relâchent ensuite. */
  const sendKey = (key: string) => {
    const active = activeOf(modifiersRef.current);
    send({ type: "key", key, modifiers: active });

    if (active.length) {
      showHud(active.map((id) => SYMBOLS[id]).join("") + (KEY_SYMBOLS[key] ?? key.toUpperCase()));
      setEcho("");
      const next = { ...modifiersRef.current };
      for (const id of active) if (next[id] === "armed") next[id] = "off";
      updateModifiers(next);
    } else if (key === "delete") {
      eraseLast();
    } else if (key === "return") {
      appendText("\n");
    } else {
      showHud(KEY_SYMBOLS[key] ?? key);
    }
  };

  /** Texte tapé : envoyé tel quel, sauf si un modificateur est actif (⌘ puis « c » = ⌘C). */
  const typeText = (text: string) => {
    let plain = "";
    const flush = () => {
      if (!plain) return;
      send({ type: "text", text: plain });
      appendText(plain);
      plain = "";
    };
    for (const character of Array.from(text)) {
      if (activeOf(modifiersRef.current).length) {
        flush();
        sendKey(character);
      } else {
        plain += character;
      }
    }
    flush();
  };

  const resetField = () => {
    const input = inputRef.current;
    if (!input) return;
    input.value = SENTINEL;
    input.setSelectionRange(SENTINEL.length, SENTINEL.length);
  };

  /** Compare le champ au texte invisible de départ pour savoir ce qui a été tapé ou effacé. */
  const handleInput = () => {
    const input = inputRef.current;
    if (!input || composing.current) return;
    const value = input.value;

    let start = 0;
    while (start < SENTINEL.length && start < value.length && SENTINEL[start] === value[start]) start++;
    let sentinelEnd = SENTINEL.length;
    let valueEnd = value.length;
    while (sentinelEnd > start && valueEnd > start && SENTINEL[sentinelEnd - 1] === value[valueEnd - 1]) {
      sentinelEnd--;
      valueEnd--;
    }

    const deleted = sentinelEnd - start;
    const inserted = value.slice(start, valueEnd).replaceAll(ZERO_WIDTH_SPACE, "");
    for (let i = 0; i < deleted; i++) sendKey("delete");
    if (inserted) typeText(inserted);
    resetField();
  };

  const keepKeyboardOpen = () => {
    if (focusedRef.current) inputRef.current?.focus();
  };

  const tapModifier = (id: KeyModifier) => {
    if (disabled) return;
    const now = performance.now();
    const current = modifiersRef.current[id];
    const isDoubleTap = current === "armed" && lastTap.current?.id === id && now - lastTap.current.time < DOUBLE_TAP_MS;
    const next: ModifierState = isDoubleTap ? "locked" : current === "off" ? "armed" : "off";
    lastTap.current = { id, time: now };
    updateModifiers({ ...modifiersRef.current, [id]: next });
    onFeedback();
    keepKeyboardOpen();
  };

  const caret = focused && <span className="type-area__caret" />;

  return (
    <section className="deck deck--typing" aria-label="Clavier">
      <label className="type-area" data-focused={focused || undefined} data-disabled={disabled || undefined}>
        <div ref={echoRef} className="type-area__echo" aria-hidden>
          {echo ? (
            <>
              {echo}
              {caret}
            </>
          ) : (
            <span className="type-area__placeholder">
              {focused ? caret : <Keyboard size={20} strokeWidth={1.75} />}
              {focused ? "Écris ici, le texte part sur le Mac" : "Touche pour écrire sur le Mac"}
            </span>
          )}
        </div>

        <input
          ref={inputRef}
          className="type-area__input"
          aria-label="Écrire sur le Mac"
          type="text"
          inputMode="text"
          autoComplete="off"
          autoCorrect="off"
          autoCapitalize="off"
          spellCheck={false}
          disabled={disabled}
          defaultValue={SENTINEL}
          onFocus={() => {
            focusedRef.current = true;
            setFocused(true);
            resetField();
          }}
          onBlur={() => {
            focusedRef.current = false;
            setFocused(false);
          }}
          onInput={handleInput}
          onCompositionStart={() => {
            composing.current = true;
          }}
          onCompositionEnd={() => {
            composing.current = false;
            handleInput();
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              onFeedback();
              sendKey("return");
            }
          }}
        />

        {echo && (
          <button
            type="button"
            className="type-area__clear"
            aria-label="Effacer l’aperçu (n’efface rien sur le Mac)"
            onPointerDown={(event) => {
              event.preventDefault();
              setEcho("");
              keepKeyboardOpen();
            }}
            onClick={(event) => {
              if (event.detail === 0) setEcho("");
            }}
          >
            <CircleX size={20} strokeWidth={2} />
          </button>
        )}

        {hud && (
          <span key={hud.id} className="type-area__hud" role="status">
            {hud.label}
          </span>
        )}
      </label>

      <div className="modifier-row">
        <HoldButton
          action="tab"
          label="Tabulation"
          disabled={disabled}
          className="keycap keycap--modifier"
          onAction={(key) => {
            onFeedback();
            sendKey(key);
            keepKeyboardOpen();
          }}
        >
          <span className="keycap__symbol">⇥</span>
          <span className="keycap__word-legend">tab</span>
        </HoldButton>

        {MODIFIERS.map(({ id, symbol, legend, label }) => (
          <button
            key={id}
            type="button"
            className="keycap keycap--modifier"
            data-state={modifiers[id]}
            aria-label={label}
            aria-pressed={modifiers[id] !== "off"}
            disabled={disabled}
            onPointerDown={(event) => {
              event.preventDefault();
              tapModifier(id);
            }}
            onClick={(event) => {
              if (event.detail === 0) tapModifier(id);
            }}
            onContextMenu={(event) => event.preventDefault()}
          >
            <span className="keycap__led" aria-hidden />
            <span className="keycap__symbol">{symbol}</span>
            <span className="keycap__word-legend">{legend}</span>
            <HapticSwitch disabled={disabled} />
          </button>
        ))}
      </div>
    </section>
  );
}
