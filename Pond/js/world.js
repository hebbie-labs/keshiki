import { settings } from './settings.js';
import { drawCaustics } from './water.js';
import { addRaindrops, drawRipples, updateRipples } from './ripples.js';
import { drawFood, sinkOldFood } from './food.js';
import { createLilyPads, drawLilyPad } from './lilypads.js';
import { createDuckweed, drawDuckweed, regrowDuckweed } from './duckweed.js';
import { createSchool, drawSchool, updateSchool } from './school.js';
import { createFrog, drawFrog, updateFrog } from './frog.js';
import { drawGoose, inviteGoose, sendGooseAway, updateGoose } from './goose.js';
import { drawBall, dropBall, updateBall } from './ball.js';
import { createKoi, drawKoi, drawKoiShadow, updateKoi } from './koi.js';
import { drawSky } from './sky.js';

const KOI_COUNT = 8;

export function createWorld(width, height) {
  const world = {
    width, height,
    food: [], ripples: [], fireflies: [],
    goose: null, ball: null, greeting: null, usualSpot: null,
  };
  world.pads = createLilyPads(world);
  world.duckweed = createDuckweed(world);
  world.school = createSchool(world);
  world.frog = createFrog(world.pads);
  world.kois = Array.from({ length: KOI_COUNT }, (_, i) => createKoi(world, i));
  return world;
}

export function updateWorld(world, dt) {
  sinkOldFood(world, dt);
  regrowDuckweed(world, dt);
  updateSchool(world, dt);
  for (const koi of world.kois) updateKoi(koi, world, dt);
  updateFrog(world, dt);
  updateGoose(world, dt);
  updateBall(world, dt);
  if (settings.rain) addRaindrops(world);
  updateRipples(world, dt);
}

/** Back to front: the pond floor, things under water, things floating, then light. */
export function drawWorld(world, time, phase) {
  drawCaustics(world, time);
  world.kois.forEach(drawKoiShadow);
  drawSchool(world.school);
  world.kois.forEach(drawKoi);
  drawFood(world);
  drawDuckweed(world);
  for (const pad of world.pads) drawLilyPad(pad, time);
  drawFrog(world.frog, time);
  drawBall(world.ball);
  drawGoose(world.goose, time);
  drawRipples(world);
  drawSky(world, phase, settings.rain, time);
}

export function inviteVisitor(world, visitor) {
  if (visitor === 'goose') inviteGoose(world);
  if (visitor === 'ball') dropBall(world);
  if (visitor === 'clear') {
    sendGooseAway(world.goose);
    world.ball = null;
  }
}
