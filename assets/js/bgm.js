import anthemicElectroHouse from "../static/sounds/music/01 Anthemic Electro House.mp3";
import boldElectroHouse from "../static/sounds/music/02 Bold Electro House.mp3";
import catchyElectroHouse from "../static/sounds/music/03 Catchy Electro House.mp3";
import drivingElectroHouse from "../static/sounds/music/04 Driving Electro House.mp3";
import forcefulElectroHouse from "../static/sounds/music/05 Forceful Electro House.mp3";
import livelyElectroHouse from "../static/sounds/music/06 Lively Electro House.mp3";
import motivationalElectroHouse from "../static/sounds/music/07 Motivational Electro House.mp3";
import strongElectroHouse from "../static/sounds/music/08 Strong Electro House.mp3";

const TRACKS = [
  anthemicElectroHouse,
  boldElectroHouse,
  catchyElectroHouse,
  drivingElectroHouse,
  forcefulElectroHouse,
  livelyElectroHouse,
  motivationalElectroHouse,
  strongElectroHouse
];

const MUSIC_VOLUME = 0.18;

export function createBgmController() {
  const supported = typeof Audio === "function";
  const listeners = new Set();
  let audio = null;
  let enabled = false;
  let trackIndex = 0;

  const snapshot = () => ({ enabled, supported });
  const notify = () => listeners.forEach((listener) => listener(snapshot()));

  const play = () => {
    if (!audio || !enabled) {
      return;
    }

    audio.play().catch(() => {
      enabled = false;
      notify();
    });
  };

  const loadTrack = () => {
    if (!audio) {
      return;
    }

    audio.src = TRACKS[trackIndex];
    audio.load();
    play();
  };

  const ensureAudio = () => {
    if (audio || !supported) {
      return;
    }

    audio = new Audio(TRACKS[trackIndex]);
    audio.preload = "metadata";
    audio.volume = MUSIC_VOLUME;
    audio.addEventListener("ended", () => {
      trackIndex = (trackIndex + 1) % TRACKS.length;
      loadTrack();
    });
  };

  return {
    getSnapshot: snapshot,
    setEnabled(nextEnabled) {
      enabled = !!nextEnabled;

      if (!enabled) {
        audio?.pause();
        if (audio) {
          audio.currentTime = 0;
        }
        notify();
        return;
      }

      ensureAudio();
      play();
      notify();
    },
    subscribe(listener) {
      listeners.add(listener);
      listener(snapshot());
      return () => listeners.delete(listener);
    },
    destroy() {
      audio?.pause();
      audio = null;
      listeners.clear();
    }
  };
}
