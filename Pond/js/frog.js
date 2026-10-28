import { distance, pick, random } from './math.js';
import { SHADOW, disc, rect } from './pixel.js';
import { padSurfaceY } from './lilypads.js';
import { addRipple } from './ripples.js';

const JUMP_SECONDS = 0.8;
const JUMP_HEIGHT = 24;
const MAX_JUMP_DISTANCE = 300;
const REST_SECONDS = [15, 45];
const GREEN = '#5fa83a';

export function createFrog(pads) {
  return { pad: pads[0], jump: null, restingFor: random(10, 30), blinkIn: 0 };
}

export function updateFrog(world, dt) {
  const frog = world.frog;
  frog.restingFor -= dt;
  frog.blinkIn -= dt;
  if (frog.blinkIn < -0.15) frog.blinkIn = random(2, 6);
  if (!frog.jump && frog.restingFor <= 0) startJump(frog, world);
  if (frog.jump && (frog.jump.progress += dt / JUMP_SECONDS) >= 1) land(frog, world);
}

export function drawFrog(frog, time) {
  const { x, y, lift } = frogPosition(frog, time);
  disc(x + 3 + lift * 0.3, y + 4 + lift * 0.4, 6, SHADOW);
  const top = y - lift;
  disc(x - 5, top + 4, 2.5, '#3f7d2c');
  disc(x + 5, top + 4, 2.5, '#3f7d2c');
  disc(x, top, 6, GREEN);
  disc(x, top + 1, 4, '#78bf4c');
  for (const side of [-1, 1]) {
    disc(x + side * 3.5, top - 4.5, 2.2, GREEN);
    rect(x + side * 3.5, top - 5, 1, 1, frog.blinkIn < 0 ? GREEN : '#141414');
  }
}

function startJump(frog, world) {
  const target = pick(world.pads.filter(pad => pad !== frog.pad && distance(pad, frog.pad) < MAX_JUMP_DISTANCE)) ?? pick(world.pads);
  frog.jump = { from: frog.pad, to: target, progress: 0 };
  frog.restingFor = random(...REST_SECONDS);
  addRipple(world, frog.pad.x, frog.pad.y, 4, 0.7);
}

function land(frog, world) {
  frog.pad = frog.jump.to;
  frog.jump = null;
  addRipple(world, frog.pad.x, frog.pad.y, frog.pad.radius * 0.6, 0.8);
}

function frogPosition(frog, time) {
  if (!frog.jump) return { x: frog.pad.x - 2, y: padSurfaceY(frog.pad, time), lift: 0 };
  const { from, to, progress } = frog.jump;
  return {
    x: from.x + (to.x - from.x) * progress,
    y: from.y + (to.y - from.y) * progress,
    lift: Math.sin(progress * Math.PI) * JUMP_HEIGHT,
  };
}
