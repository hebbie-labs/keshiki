import { distance, pick, random } from './math.js';
import { rect } from './pixel.js';

const PATCH_COUNT = 4;
const LEAVES_PER_PATCH = 70;
const PATCH_RADIUS = 30;
const REGROW_SECONDS = [40, 120];
const GREENS = ['#8cc152', '#a0d468', '#7cb342'];

/** Little floating patches the koi graze; eaten leaves grow back. */
export function createDuckweed(world) {
  const leaves = [];
  for (let patch = 0; patch < PATCH_COUNT; patch++) {
    const center = { x: random(80, world.width - 80), y: random(60, world.height - 60) };
    for (let i = 0; i < LEAVES_PER_PATCH; i++) {
      const angle = random(0, 6.28), reach = Math.sqrt(Math.random()) * PATCH_RADIUS;
      leaves.push({ x: center.x + Math.cos(angle) * reach * 1.4, y: center.y + Math.sin(angle) * reach, eaten: false, regrowIn: 0, color: pick(GREENS) });
    }
  }
  return leaves;
}

export function regrowDuckweed(world, dt) {
  for (const leaf of world.duckweed) {
    if (leaf.eaten && (leaf.regrowIn -= dt) <= 0) leaf.eaten = false;
  }
}

/** Eats every leaf within reach; true if anything was eaten. */
export function grazeDuckweed(world, point, reach) {
  let grazed = false;
  for (const leaf of world.duckweed) {
    if (leaf.eaten || distance(leaf, point) >= reach) continue;
    leaf.eaten = true;
    leaf.regrowIn = random(...REGROW_SECONDS);
    grazed = true;
  }
  return grazed;
}

export function randomLeaf(world) {
  const growing = world.duckweed.filter(leaf => !leaf.eaten);
  return growing.length ? pick(growing) : null;
}

export function drawDuckweed(world) {
  for (const leaf of world.duckweed) if (!leaf.eaten) rect(leaf.x, leaf.y, 2, 2, leaf.color);
}
