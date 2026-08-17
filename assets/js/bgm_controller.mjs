export const MUSIC_ENABLED_COOKIE = "hermes-trictrac:music-enabled";
export const MUSIC_SESSION_KEY = "hermes-trictrac:bgm-session";

const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365;

function defaultWindow() {
  return typeof window === "undefined" ? null : window;
}

function defaultDocument() {
  return typeof document === "undefined" ? null : document;
}

function defaultSessionStorage(windowRef) {
  try {
    return windowRef?.sessionStorage || null;
  } catch (_error) {
    return null;
  }
}

function parseEnabledCookie(cookie = "") {
  const prefix = `${MUSIC_ENABLED_COOKIE}=`;
  const value = String(cookie)
    .split(";")
    .map((entry) => entry.trim())
    .find((entry) => entry.startsWith(prefix))
    ?.slice(prefix.length);

  return value === "false" ? false : true;
}

function writeEnabledCookie(documentRef, locationRef, enabled) {
  if (!documentRef) {
    return;
  }

  const secure = locationRef?.protocol === "https:" ? "; Secure" : "";

  documentRef.cookie = [
    `${MUSIC_ENABLED_COOKIE}=${enabled ? "true" : "false"}`,
    "Path=/",
    `Max-Age=${COOKIE_MAX_AGE_SECONDS}`,
    "SameSite=Lax"
  ].join("; ") + secure;
}

function readSession(storage, trackCount) {
  try {
    const stored = JSON.parse(storage?.getItem(MUSIC_SESSION_KEY) || "null");
    const trackIndex = Number(stored?.trackIndex);
    const position = Number(stored?.position);

    if (Number.isInteger(trackIndex) && trackIndex >= 0 && trackIndex < trackCount) {
      return {
        trackIndex,
        position: Number.isFinite(position) && position >= 0 ? position : 0
      };
    }
  } catch (_error) {
    // Session storage is an enhancement. A fresh random start is still valid.
  }

  return null;
}

function writeSession(storage, trackIndex, position) {
  try {
    storage?.setItem(
      MUSIC_SESSION_KEY,
      JSON.stringify({
        trackIndex,
        position: Number.isFinite(position) && position >= 0 ? position : 0
      })
    );
  } catch (_error) {
    // Session storage can be unavailable in restricted browser contexts.
  }
}

function randomTrackIndex(trackCount, random) {
  if (trackCount <= 1) {
    return 0;
  }

  const value = Number(random());
  const normalized = Number.isFinite(value) ? value : 0;
  return Math.min(trackCount - 1, Math.max(0, Math.floor(normalized * trackCount)));
}

export function createPersistentBgmController({
  tracks = [],
  AudioCtor = typeof Audio === "function" ? Audio : null,
  windowRef = defaultWindow(),
  documentRef = defaultDocument(),
  storage = defaultSessionStorage(windowRef),
  locationRef = windowRef?.location,
  random = Math.random,
  volume = 0.18
} = {}) {
  const playableTracks = Array.from(tracks).filter(Boolean);
  const listeners = new Set();
  const supported = typeof AudioCtor === "function";
  let available = supported && playableTracks.length > 0;
  const storedSession = readSession(storage, playableTracks.length);
  let trackIndex = storedSession?.trackIndex ?? randomTrackIndex(playableTracks.length, random);
  let resumePosition = storedSession?.position ?? 0;
  let enabled = parseEnabledCookie(documentRef?.cookie);
  let awaitingInteraction = false;
  let audio = null;
  let destroyed = false;
  let failuresInSequence = 0;
  let playbackAttempt = 0;
  let unlockListening = false;

  const snapshot = () => ({
    enabled,
    supported,
    available,
    awaitingInteraction,
    trackIndex,
    trackCount: playableTracks.length
  });

  const notify = () => listeners.forEach((listener) => listener(snapshot()));

  const currentPosition = () => {
    const readyState = Number(audio?.readyState);

    if (resumePosition > 0 && Number.isFinite(readyState) && readyState < 1) {
      return resumePosition;
    }

    const position = Number(audio?.currentTime);
    return Number.isFinite(position) && position >= 0 ? position : resumePosition;
  };

  const persistSession = () => {
    writeSession(storage, trackIndex, currentPosition());
  };

  const removeUnlockListeners = () => {
    if (!unlockListening || !windowRef) {
      return;
    }

    windowRef.removeEventListener("pointerdown", retryAfterGesture);
    windowRef.removeEventListener("touchstart", retryAfterGesture);
    windowRef.removeEventListener("keydown", retryAfterGesture);
    unlockListening = false;
  };

  const listenForUnlock = () => {
    if (unlockListening || !windowRef || !enabled || !available) {
      return;
    }

    windowRef.addEventListener("pointerdown", retryAfterGesture, { passive: true });
    windowRef.addEventListener("touchstart", retryAfterGesture, { passive: true });
    windowRef.addEventListener("keydown", retryAfterGesture);
    unlockListening = true;
  };

  const restorePosition = () => {
    if (!audio || !resumePosition) {
      return;
    }

    const duration = Number(audio.duration);
    const position = Number.isFinite(duration) && duration > 0
      ? Math.min(resumePosition, Math.max(0, duration - 0.01))
      : resumePosition;

    try {
      audio.currentTime = position;
    } catch (_error) {
      // Some browsers only permit seeking after metadata has loaded.
      return;
    }

    resumePosition = 0;
  };

  const play = () => {
    if (!audio || !enabled || !available || destroyed) {
      return;
    }

    const attempt = ++playbackAttempt;
    let playback;

    try {
      playback = audio.play?.();
    } catch (_error) {
      awaitingInteraction = true;
      listenForUnlock();
      notify();
      return;
    }

    if (!playback || typeof playback.then !== "function") {
      awaitingInteraction = false;
      removeUnlockListeners();
      notify();
      return;
    }

    playback
      .then(() => {
        if (attempt !== playbackAttempt || !enabled || destroyed) {
          return;
        }

        awaitingInteraction = false;
        removeUnlockListeners();
        notify();
      })
      .catch(() => {
        if (attempt !== playbackAttempt || !enabled || destroyed) {
          return;
        }

        awaitingInteraction = true;
        listenForUnlock();
        notify();
      });
  };

  const loadTrack = () => {
    if (!audio || !available) {
      return;
    }

    audio.src = playableTracks[trackIndex];
    audio.load?.();
    restorePosition();
    persistSession();
    play();
  };

  const skipFailedTrack = () => {
    if (!enabled || !available) {
      return;
    }

    failuresInSequence += 1;

    if (failuresInSequence >= playableTracks.length) {
      available = false;
      awaitingInteraction = false;
      removeUnlockListeners();
      notify();
      return;
    }

    trackIndex = (trackIndex + 1) % playableTracks.length;
    resumePosition = 0;
    persistSession();
    loadTrack();
  };

  const ensureAudio = () => {
    if (audio || !available || destroyed) {
      return;
    }

    audio = new AudioCtor();
    audio.preload = "metadata";
    audio.volume = volume;
    audio.addEventListener("loadedmetadata", restorePosition);
    audio.addEventListener("timeupdate", persistSession);
    audio.addEventListener("pause", persistSession);
    audio.addEventListener("playing", () => {
      failuresInSequence = 0;
    });
    audio.addEventListener("error", skipFailedTrack);
    audio.addEventListener("ended", () => {
      failuresInSequence = 0;
      trackIndex = (trackIndex + 1) % playableTracks.length;
      resumePosition = 0;
      persistSession();
      loadTrack();
    });
    loadTrack();
  };

  function retryAfterGesture() {
    removeUnlockListeners();
    play();
  }

  const persistWhenHidden = () => {
    if (documentRef?.visibilityState === "hidden") {
      persistSession();
    }
  };

  if (windowRef) {
    windowRef.addEventListener("pagehide", persistSession);
  }

  documentRef?.addEventListener?.("visibilitychange", persistWhenHidden);

  return {
    getSnapshot: snapshot,
    start() {
      if (enabled) {
        const alreadyInitialized = !!audio;
        ensureAudio();
        if (alreadyInitialized) {
          play();
        }
      }

      notify();
    },
    setEnabled(nextEnabled) {
      enabled = !!nextEnabled;
      writeEnabledCookie(documentRef, locationRef, enabled);

      if (!enabled) {
        playbackAttempt += 1;
        awaitingInteraction = false;
        removeUnlockListeners();
        audio?.pause?.();
        persistSession();
        notify();
        return;
      }

      const alreadyInitialized = !!audio;
      ensureAudio();
      if (alreadyInitialized) {
        play();
      }
      notify();
    },
    subscribe(listener) {
      listeners.add(listener);
      listener(snapshot());
      return () => listeners.delete(listener);
    },
    persist: persistSession,
    destroy() {
      if (destroyed) {
        return;
      }

      destroyed = true;
      playbackAttempt += 1;
      persistSession();
      removeUnlockListeners();
      audio?.pause?.();
      windowRef?.removeEventListener("pagehide", persistSession);
      documentRef?.removeEventListener?.("visibilitychange", persistWhenHidden);
      listeners.clear();
      audio = null;
    }
  };
}
