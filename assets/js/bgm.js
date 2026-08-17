import anthemicElectroHouse from "../static/sounds/music/01 Anthemic Electro House.mp3";
import boldElectroHouse from "../static/sounds/music/02 Bold Electro House.mp3";
import catchyElectroHouse from "../static/sounds/music/03 Catchy Electro House.mp3";
import drivingElectroHouse from "../static/sounds/music/04 Driving Electro House.mp3";
import forcefulElectroHouse from "../static/sounds/music/05 Forceful Electro House.mp3";
import livelyElectroHouse from "../static/sounds/music/06 Lively Electro House.mp3";
import motivationalElectroHouse from "../static/sounds/music/07 Motivational Electro House.mp3";
import strongElectroHouse from "../static/sounds/music/08 Strong Electro House.mp3";
import { createPersistentBgmController } from "./bgm_controller.mjs";

export const BGM_TRACKS = [
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
let sharedController = null;

export function createBgmController(options = {}) {
  return createPersistentBgmController({
    tracks: BGM_TRACKS,
    volume: MUSIC_VOLUME,
    ...options
  });
}

export function getBgmController() {
  if (!sharedController) {
    sharedController = createBgmController();
  }

  return sharedController;
}
