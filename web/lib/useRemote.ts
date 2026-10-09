"use client";

import { useCallback, useEffect, useRef, useState } from "react";

export type RemoteAction =
  | "playPause"
  | "seekBackward"
  | "seekForward"
  | "volumeUp"
  | "volumeDown"
  | "mute"
  | "fullscreen"
  | "escape";

export type RemoteState = {
  app: string;
  profile: string;
  accessibility: boolean;
};

export type PointerMessage =
  | { type: "move"; dx: number; dy: number }
  | { type: "scroll"; dx: number; dy: number }
  | { type: "click"; button: "left" | "right" }
  | { type: "button"; button: "left" | "right"; down: boolean };

export type KeyModifier = "shift" | "control" | "option" | "command";

export type KeyboardMessage =
  | { type: "text"; text: string }
  | { type: "key"; key: string; modifiers: KeyModifier[] }
  | { type: "modifiers"; held: KeyModifier[] };

export type ConnectionStatus =
  | "no-token"
  | "bad-token"
  | "connecting"
  | "connected"
  | "disconnected";

type ServerMessage =
  | { type: "welcome"; state: RemoteState }
  | { type: "state"; state: RemoteState }
  | { type: "pong" }
  | { type: "error"; reason: "bad_token" | "token_revoked" };

const TOKEN_KEY = "macremote.token";

/**
 * Le jeton arrive dans le fragment (#t=…) du lien du QR code.
 * On le garde dans l'URL (pour « Ajouter à l'écran d'accueil ») et dans localStorage.
 */
function readToken(): string | null {
  const match = window.location.hash.match(/[#&]t=([^&]+)/);
  if (match) {
    try {
      localStorage.setItem(TOKEN_KEY, match[1]);
    } catch {}
    return match[1];
  }
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

function forgetToken() {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {}
}

function socketURL(): string {
  const { protocol, hostname, port } = window.location;
  const host = hostname.includes(":") ? `[${hostname}]` : hostname;
  const wsPort = process.env.NEXT_PUBLIC_WS_PORT || port;
  return `${protocol === "https:" ? "wss" : "ws"}://${host}${wsPort ? `:${wsPort}` : ""}/ws`;
}

export function useRemote() {
  const [status, setStatus] = useState<ConnectionStatus>("connecting");
  const [state, setState] = useState<RemoteState | null>(null);
  const [pulse, setPulse] = useState(0);
  const socketRef = useRef<WebSocket | null>(null);
  const authenticatedRef = useRef(false);

  useEffect(() => {
    const token = readToken();
    if (!token) {
      setStatus("no-token");
      return;
    }

    let stopped = false;
    let attempt = 0;
    let retryTimer: number | undefined;
    let pongTimer: number | undefined;

    const connect = () => {
      if (stopped) return;
      window.clearTimeout(retryTimer);
      setStatus("connecting");

      const socket = new WebSocket(socketURL());
      socketRef.current = socket;
      authenticatedRef.current = false;

      socket.onopen = () => socket.send(JSON.stringify({ type: "hello", token }));

      socket.onmessage = (event) => {
        const message = JSON.parse(event.data) as ServerMessage;
        switch (message.type) {
          case "welcome":
            attempt = 0;
            authenticatedRef.current = true;
            setStatus("connected");
            setState(message.state);
            break;
          case "state":
            setState(message.state);
            break;
          case "pong":
            window.clearTimeout(pongTimer);
            break;
          case "error":
            stopped = true;
            forgetToken();
            setStatus("bad-token");
            socket.close();
            break;
        }
      };

      socket.onclose = () => {
        if (socketRef.current === socket) socketRef.current = null;
        authenticatedRef.current = false;
        if (stopped) return;
        setStatus("disconnected");
        retryTimer = window.setTimeout(connect, Math.min(500 * 2 ** attempt, 5000));
        attempt += 1;
      };
    };

    const onVisibilityChange = () => {
      if (document.visibilityState !== "visible" || stopped) return;
      const socket = socketRef.current;
      if (!socket || socket.readyState >= WebSocket.CLOSING) {
        attempt = 0;
        connect();
      } else if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: "ping" }));
        window.clearTimeout(pongTimer);
        pongTimer = window.setTimeout(() => socket.close(), 1500);
      }
    };

    connect();
    document.addEventListener("visibilitychange", onVisibilityChange);

    return () => {
      stopped = true;
      window.clearTimeout(retryTimer);
      window.clearTimeout(pongTimer);
      document.removeEventListener("visibilitychange", onVisibilityChange);
      socketRef.current?.close();
    };
  }, []);

  const transmit = useCallback((payload: object) => {
    const socket = socketRef.current;
    if (!socket || socket.readyState !== WebSocket.OPEN || !authenticatedRef.current) return false;
    socket.send(JSON.stringify(payload));
    return true;
  }, []);

  const send = useCallback(
    (action: RemoteAction) => {
      if (transmit({ type: "action", action })) setPulse((n) => n + 1);
    },
    [transmit],
  );

  /**
   * Souris. Renvoie false si le message n'est pas parti : pour move/scroll,
   * on n'empile pas les messages quand le réseau traîne (l'appelant cumule et réessaie).
   */
  const sendPointer = useCallback(
    (message: PointerMessage) => {
      const congested = (socketRef.current?.bufferedAmount ?? 0) > 2048;
      if ((message.type === "move" || message.type === "scroll") && congested) return false;
      const sent = transmit(message);
      if (sent && (message.type === "click" || (message.type === "button" && message.down))) {
        setPulse((n) => n + 1);
      }
      return sent;
    },
    [transmit],
  );

  const sendKeyboard = useCallback((message: KeyboardMessage) => transmit(message), [transmit]);

  return { status, state, send, sendPointer, sendKeyboard, pulse };
}
