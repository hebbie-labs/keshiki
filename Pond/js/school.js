import { clamp, distance, random, randomPointIn } from './math.js';
import { rect } from './pixel.js';

const SCHOOL_SIZE = 14;
const SCARE_RADIUS = 40;
const DAMPING = 0.93;

/** A school of tiny fish that drifts around and scatters from the koi, so a koi can herd it. */
export function createSchool(world) {
  const center = randomPointIn(world, 100, 80);
  return {
    center,
    destination: { ...center },
    fish: Array.from({ length: SCHOOL_SIZE }, () => ({ x: center.x + random(-20, 20), y: center.y + random(-20, 20), vx: 0, vy: 0 })),
  };
}

export function updateSchool(world, dt) {
  const school = world.school;
  if (distance(school.destination, school.center) < 10) school.destination = randomPointIn(world, 60, 50);
  school.center.x += (school.destination.x - school.center.x) * 0.004 * dt * 60;
  school.center.y += (school.destination.y - school.center.y) * 0.004 * dt * 60;
  for (const fish of school.fish) swim(fish, school, world, dt);
  recenter(school);
}

export function drawSchool(school) {
  for (const fish of school.fish) {
    const heading = Math.atan2(fish.vy, fish.vx) || 0;
    rect(fish.x + 3, fish.y + 4, 3, 1, 'rgba(0,15,8,0.25)');
    for (let step = 0; step < 6; step++) {
      const size = step < 3 ? 2 : 1;
      rect(fish.x - Math.cos(heading) * step, fish.y - Math.sin(heading) * step, size, size, '#d6e2cc');
    }
  }
}

function swim(fish, school, world, dt) {
  fish.vx += (school.center.x - fish.x) * 0.002 + random(-0.08, 0.08);
  fish.vy += (school.center.y - fish.y) * 0.002 + random(-0.08, 0.08);
  for (const koi of world.kois) fleeFrom(koi.body[0], fish, school, world);
  fish.vx *= DAMPING;
  fish.vy *= DAMPING;
  fish.x = clamp(fish.x + fish.vx * dt * 60, 3, world.width - 3);
  fish.y = clamp(fish.y + fish.vy * dt * 60, 3, world.height - 3);
}

function fleeFrom(predator, fish, school, world) {
  const d = distance(predator, fish);
  if (d >= SCARE_RADIUS) return;
  fish.vx += (fish.x - predator.x) / d * 0.35;
  fish.vy += (fish.y - predator.y) / d * 0.35;
  school.destination = {
    x: clamp(fish.x + (fish.x - predator.x) * 3, 40, world.width - 40),
    y: clamp(fish.y + (fish.y - predator.y) * 3, 40, world.height - 40),
  };
}

function recenter(school) {
  const averageX = school.fish.reduce((sum, fish) => sum + fish.x, 0) / school.fish.length;
  const averageY = school.fish.reduce((sum, fish) => sum + fish.y, 0) / school.fish.length;
  school.center.x += (averageX - school.center.x) * 0.02;
  school.center.y += (averageY - school.center.y) * 0.02;
}
