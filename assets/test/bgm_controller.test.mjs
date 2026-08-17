import assert from "node:assert/strict";
import test from "node:test";
import {
  MUSIC_ENABLED_COOKIE,
  MUSIC_SESSION_KEY,
  createPersistentBgmController
} from "../js/bgm_controller.mjs";

const TRACKS = Array.from({ length: 8 }, (_, index) => `track-${index + 1}`);

class FakeEventTarget {
  #listeners = new Map();

  addEventListener(type, listener) {
    const listeners = this.#listeners.get(type) || new Set();
    listeners.add(listener);
    this.#listeners.set(type, listeners);
  }

  removeEventListener(type, listener) {
    this.#listeners.get(type)?.delete(listener);
  }

  emit(type) {
    this.#listeners.get(type)?.forEach((listener) => listener({ type }));
  }
}

class MemoryStorage {
  #values = new Map();

  getItem(key) {
    return this.#values.get(key) || null;
  }

  setItem(key, value) {
    this.#values.set(key, String(value));
  }
}

class FakeAudio extends FakeEventTarget {
  static instances = [];
  static playResult = () => Promise.resolve();

  constructor() {
    super();
    this.currentTime = 0;
    this.duration = 120;
    this.volume = 0;
    this.preload = "";
    this.src = "";
    this.paused = false;
    this.playCalls = 0;
    FakeAudio.instances.push(this);
  }

  load() {}

  play() {
    this.playCalls += 1;
    return FakeAudio.playResult();
  }

  pause() {
    this.paused = true;
    this.emit("pause");
  }
}

function makeEnvironment({ cookie = "", storage = new MemoryStorage() } = {}) {
  const windowRef = new FakeEventTarget();
  windowRef.sessionStorage = storage;
  windowRef.location = { protocol: "https:" };

  const documentRef = new FakeEventTarget();
  const writes = [];
  let cookieValue = cookie;
  Object.defineProperty(documentRef, "cookie", {
    get: () => cookieValue,
    set: (value) => {
      writes.push(value);
      cookieValue = value;
    }
  });
  documentRef.visibilityState = "visible";

  return { documentRef, storage, windowRef, writes };
}

function makeController(environment, options = {}) {
  return createPersistentBgmController({
    tracks: TRACKS,
    AudioCtor: FakeAudio,
    documentRef: environment.documentRef,
    storage: environment.storage,
    windowRef: environment.windowRef,
    locationRef: environment.windowRef.location,
    ...options
  });
}

async function settlePlayback() {
  await Promise.resolve();
  await Promise.resolve();
}

test.beforeEach(() => {
  FakeAudio.instances = [];
  FakeAudio.playResult = () => Promise.resolve();
});

test("starts enabled at one random track, then advances in numeric order and wraps", () => {
  const environment = makeEnvironment();
  const controller = makeController(environment, { random: () => 0.49 });

  assert.deepEqual(controller.getSnapshot(), {
    enabled: true,
    supported: true,
    available: true,
    awaitingInteraction: false,
    trackIndex: 3,
    trackCount: 8
  });

  controller.start();
  const audio = FakeAudio.instances[0];
  assert.equal(audio.src, "track-4");

  audio.emit("ended");
  assert.equal(audio.src, "track-5");
  assert.equal(controller.getSnapshot().trackIndex, 4);

  for (let index = 0; index < 4; index += 1) {
    audio.emit("ended");
  }

  assert.equal(audio.src, "track-1");
  assert.equal(controller.getSnapshot().trackIndex, 0);
});

test("persists the enabled choice in a durable secure cookie and resumes after Off", () => {
  const environment = makeEnvironment({ cookie: `${MUSIC_ENABLED_COOKIE}=false` });
  const controller = makeController(environment, { random: () => 0 });

  assert.equal(controller.getSnapshot().enabled, false);
  controller.setEnabled(true);
  assert.match(environment.writes.at(-1), new RegExp(`^${MUSIC_ENABLED_COOKIE}=true`));
  assert.match(environment.writes.at(-1), /Path=\//);
  assert.match(environment.writes.at(-1), /Max-Age=31536000/);
  assert.match(environment.writes.at(-1), /SameSite=Lax/);
  assert.match(environment.writes.at(-1), /Secure/);

  const audio = FakeAudio.instances[0];
  controller.setEnabled(false);
  assert.equal(audio.paused, true);
  assert.equal(controller.getSnapshot().enabled, false);
  controller.setEnabled(true);
  assert.equal(audio.src, "track-1");
});

test("restores the active track and playback position for a full-page navigation in one tab", () => {
  const environment = makeEnvironment();
  const first = makeController(environment, { random: () => 0.8 });
  first.start();
  const firstAudio = FakeAudio.instances[0];
  firstAudio.currentTime = 37.25;
  environment.windowRef.emit("pagehide");

  assert.deepEqual(JSON.parse(environment.storage.getItem(MUSIC_SESSION_KEY)), {
    trackIndex: 6,
    position: 37.25
  });

  const nextEnvironment = makeEnvironment({ storage: environment.storage });
  const second = makeController(nextEnvironment, { random: () => 0 });
  second.start();
  const secondAudio = FakeAudio.instances[1];
  secondAudio.emit("loadedmetadata");

  assert.equal(second.getSnapshot().trackIndex, 6);
  assert.equal(secondAudio.src, "track-7");
  assert.equal(secondAudio.currentTime, 37.25);
});

test("an autoplay rejection leaves music enabled and retries on the first gesture", async () => {
  let rejected = true;
  FakeAudio.playResult = () => rejected ? Promise.reject(new Error("autoplay blocked")) : Promise.resolve();
  const environment = makeEnvironment();
  const controller = makeController(environment, { random: () => 0 });

  controller.start();
  await settlePlayback();

  assert.equal(controller.getSnapshot().enabled, true);
  assert.equal(controller.getSnapshot().awaitingInteraction, true);

  rejected = false;
  environment.windowRef.emit("pointerdown");
  await settlePlayback();

  assert.equal(controller.getSnapshot().enabled, true);
  assert.equal(controller.getSnapshot().awaitingInteraction, false);
});

test("skips unreadable tracks without changing the enabled preference", () => {
  const environment = makeEnvironment();
  const controller = makeController(environment, { random: () => 0 });
  controller.start();
  const audio = FakeAudio.instances[0];

  audio.emit("error");

  assert.equal(controller.getSnapshot().enabled, true);
  assert.equal(controller.getSnapshot().trackIndex, 1);
  assert.equal(audio.src, "track-2");
});
