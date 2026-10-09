"use client";

import { useCallback, useEffect, useState } from "react";
import { Keyboard, MousePointer2, ScanQrCode, TriangleAlert, WifiOff } from "lucide-react";
import { HoldButton } from "@/components/HoldButton";
import { KeyFace, KeyFilters } from "@/components/KeyFace";
import { Trackpad } from "@/components/Trackpad";
import { TypingPad } from "@/components/TypingPad";
import { useHaptic } from "@/lib/useHaptic";
import { useRemote, type ConnectionStatus, type RemoteAction } from "@/lib/useRemote";

type Mode = "remote" | "mouse";

const MODE_KEY = "macremote.mode";

const STATUS_LABEL: Record<ConnectionStatus, string> = {
  connected: "Connecté au Mac",
  connecting: "Connexion…",
  disconnected: "Mac injoignable",
  "no-token": "Non jumelé",
  "bad-token": "Lien expiré",
};

export default function RemotePage() {
  const { status, state, send, sendPointer, sendKeyboard } = useRemote();
  const haptic = useHaptic();
  const [mode, setMode] = useState<Mode>("remote");

  useEffect(() => {
    try {
      if (localStorage.getItem(MODE_KEY) === "mouse") setMode("mouse");
    } catch {}
  }, []);

  const changeMode = (next: Mode) => {
    setMode(next);
    try {
      localStorage.setItem(MODE_KEY, next);
    } catch {}
  };

  const act = useCallback(
    (action: RemoteAction) => {
      haptic.trigger();
      send(action);
    },
    [haptic, send],
  );

  if (status === "no-token" || status === "bad-token") {
    return <Pairing expired={status === "bad-token"} />;
  }

  const live = status === "connected";
  const key = { onAction: act, disabled: !live };

  return (
    <>
      <main className="screen" data-mode={mode}>
        <KeyFilters />

        <header className="header">
          <p className="eyebrow" data-status={status}>
            <span className="dot" aria-hidden />
            {STATUS_LABEL[status]}
          </p>
          <h1 className="large-title">{state?.app ?? "Mac Remote"}</h1>
          <p className="subtitle">{state ? `Raccourcis ${state.profile.toLowerCase()}` : "En attente du Mac"}</p>
        </header>

        {!live && (
          <p className="notice">
            <WifiOff size={20} strokeWidth={2} aria-hidden />
            <span>Vérifie que le téléphone est sur le même Wi-Fi que le Mac et que Mac Remote est ouvert.</span>
          </p>
        )}
        {live && state && !state.accessibility && (
          <p className="notice notice--warning">
            <TriangleAlert size={20} strokeWidth={2} aria-hidden />
            <span>Sur le Mac, active Mac Remote dans Réglages › Confidentialité et sécurité › Accessibilité.</span>
          </p>
        )}

        {mode === "remote" ? (
          <div className="keyboard">
            <TypingPad send={sendKeyboard} onFeedback={haptic.trigger} disabled={!live} />

            <section className="deck" aria-label="Touches de fonction">
              <HoldButton {...key} action="seekBackward" label="Reculer" repeat={260} className="keycap">
                <KeyFace glyph="rewind" legend="F7" />
              </HoldButton>
              <HoldButton {...key} action="playPause" label="Lecture / pause" className="keycap">
                <KeyFace glyph="playPause" legend="F8" />
              </HoldButton>
              <HoldButton {...key} action="seekForward" label="Avancer" repeat={260} className="keycap">
                <KeyFace glyph="forward" legend="F9" />
              </HoldButton>

              <HoldButton {...key} action="mute" label="Couper le son" className="keycap">
                <KeyFace glyph="mute" legend="F10" />
              </HoldButton>
              <HoldButton {...key} action="volumeDown" label="Baisser le son" repeat={110} className="keycap">
                <KeyFace glyph="volumeDown" legend="F11" />
              </HoldButton>
              <HoldButton {...key} action="volumeUp" label="Monter le son" repeat={110} className="keycap">
                <KeyFace glyph="volumeUp" legend="F12" />
              </HoldButton>

              <HoldButton {...key} action="escape" label="Échap" className="keycap keycap--wide">
                <KeyFace word="esc" />
              </HoldButton>
              <HoldButton {...key} action="fullscreen" label="Plein écran" className="keycap keycap--wide">
                <KeyFace glyph="fullscreen" legend="fn F" />
              </HoldButton>
            </section>
          </div>
        ) : (
          <Trackpad send={sendPointer} onFeedback={haptic.trigger} disabled={!live} />
        )}
      </main>

      <nav className="tab-bar" role="tablist" aria-label="Mode">
        <button type="button" role="tab" aria-selected={mode === "remote"} onClick={() => changeMode("remote")}>
          <Keyboard size={25} strokeWidth={1.75} aria-hidden />
          Touches
        </button>
        <button type="button" role="tab" aria-selected={mode === "mouse"} onClick={() => changeMode("mouse")}>
          <MousePointer2 size={25} strokeWidth={1.75} aria-hidden />
          Trackpad
        </button>
      </nav>
    </>
  );
}

function Pairing({ expired }: { expired: boolean }) {
  return (
    <main className="pairing">
      <div className="pairing__icon" aria-hidden>
        <ScanQrCode size={40} strokeWidth={1.75} />
      </div>
      <h1 className="pairing__title">{expired ? "Lien expiré" : "Jumeler avec le Mac"}</h1>
      <p className="pairing__text">
        {expired
          ? "Ce lien n’est plus valide. Scanne le nouveau QR code affiché par Mac Remote."
          : "Sur le Mac, clique sur l’icône Mac Remote dans la barre des menus, puis scanne le QR code avec l’appareil photo."}
      </p>
    </main>
  );
}
