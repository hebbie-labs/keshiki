import { pick, random } from './math.js';
import { SHADOW, disc, rect } from './pixel.js';

const PAD_COUNT = 12;
const PLACEMENT_ATTEMPTS = 500;
const MIN_GAP = 6;
const GREENS = ['#4f8f3a', '#5a9a40', '#467f34', '#5f9f48'];

export function createLilyPads(world) {
  const pads = [];
  for (let attempt = 0; pads.length < PAD_COUNT && attempt < PLACEMENT_ATTEMPTS; attempt++) {
    const pad = {
      x: random(40, world.width - 40), y: random(40, world.height - 40), radius: random(16, 34),
      notchAngle: random(0, 6.28), color: pick(GREENS), hasFlower: Math.random() < 0.35, bobPhase: random(0, 6.28),
    };
    if (!pads.some(other => overlaps(pad, other))) pads.push(pad);
  }
  return pads;
}

/** Pads bob gently; things sitting on a pad should follow this. */
export const padSurfaceY = (pad, time) => pad.y + Math.sin(time * 0.6 + pad.bobPhase) * 1.2;

export function drawLilyPad(pad, time) {
  const y = padSurfaceY(pad, time);
  disc(pad.x + 4, y + 6, pad.radius, SHADOW);
  disc(pad.x, y, pad.radius, pad.color);
  disc(pad.x - pad.radius * 0.25, y - pad.radius * 0.25, pad.radius * 0.55, 'rgba(255,255,200,0.07)');
  drawVeins(pad, y);
  drawNotch(pad, y);
  if (pad.hasFlower) drawLotus(pad.x + 3, y - 3, pad.bobPhase);
}

function overlaps(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y) < a.radius + b.radius + MIN_GAP;
}

function drawVeins(pad, y) {
  for (let vein = 0; vein < 7; vein++) {
    const angle = pad.notchAngle + 0.6 + vein * 0.75;
    for (let step = 3; step < pad.radius - 2; step += 2) {
      rect(pad.x + Math.cos(angle) * step, y + Math.sin(angle) * step, 1, 1, 'rgba(30,70,30,0.35)');
    }
  }
}

function drawNotch(pad, y) {
  for (let step = 2; step < pad.radius + 1; step++) {
    const size = Math.max(1, Math.round(step * 0.28));
    rect(pad.x + Math.cos(pad.notchAngle) * step - size / 2, y + Math.sin(pad.notchAngle) * step - size / 2, size, size, '#16402f');
  }
}

function drawLotus(x, y, rotation) {
  for (let petal = 0; petal < 6; petal++) {
    const angle = petal / 6 * Math.PI * 2 + rotation;
    disc(x + Math.cos(angle) * 4, y + Math.sin(angle) * 4, 3, '#f0a9bf');
  }
  disc(x, y, 3.5, '#fbd3e0');
  disc(x, y, 1.5, '#f7d35c');
}
