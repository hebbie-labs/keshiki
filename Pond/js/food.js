import { distance, random } from './math.js';
import { rect } from './pixel.js';
import { addRipple } from './ripples.js';

const PELLETS_PER_DROP = 8;
const SECONDS_AFLOAT = 30;

export function dropFood(world, point) {
  addRipple(world, point.x, point.y);
  for (let i = 0; i < PELLETS_PER_DROP; i++) {
    world.food.push({ x: point.x + random(-10, 10), y: point.y + random(-8, 8), secondsLeft: SECONDS_AFLOAT });
  }
}

export function sinkOldFood(world, dt) {
  for (const pellet of world.food) pellet.secondsLeft -= dt;
  world.food = world.food.filter(pellet => pellet.secondsLeft > 0);
}

export function nearestFood(world, point, range) {
  let nearest = null, nearestDistance = range;
  for (const pellet of world.food) {
    const d = distance(pellet, point);
    if (d < nearestDistance) { nearest = pellet; nearestDistance = d; }
  }
  return nearest;
}

export function eatFoodNear(world, point, reach) {
  const pellet = nearestFood(world, point, reach);
  if (!pellet) return;
  world.food.splice(world.food.indexOf(pellet), 1);
  addRipple(world, pellet.x, pellet.y);
}

export function drawFood(world) {
  for (const pellet of world.food) rect(pellet.x, pellet.y, 2, 2, '#c98a3e');
}
