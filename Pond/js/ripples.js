import { random } from './math.js';
import { ring } from './pixel.js';

const GROWTH_PER_SECOND = 26;
const FADE_PER_SECOND = 0.8;
const RAINDROPS_PER_FRAME = 3;

export function addRipple(world, x, y, radius = 1, life = 1) {
  world.ripples.push({ x, y, radius, life });
}

export function addRaindrops(world) {
  for (let i = 0; i < RAINDROPS_PER_FRAME; i++) {
    if (Math.random() < 0.6) addRipple(world, random(0, world.width), random(0, world.height), 0.5, 0.6);
  }
}

export function updateRipples(world, dt) {
  for (const ripple of world.ripples) {
    ripple.radius += dt * GROWTH_PER_SECOND;
    ripple.life -= dt * FADE_PER_SECOND;
  }
  world.ripples = world.ripples.filter(ripple => ripple.life > 0);
}

export function drawRipples(world) {
  for (const ripple of world.ripples) ring(ripple.x, ripple.y, ripple.radius, `rgba(220,255,240,${ripple.life * 0.55})`);
}
