import { disc, fill, rect } from './pixel.js';
import { random } from './math.js';

const TINTS = {
  dawn:   'rgba(255,170,190,0.13)',
  day:    'rgba(255,255,230,0.03)',
  golden: 'rgba(255,170,60,0.18)',
  dusk:   'rgba(90,40,120,0.30)',
  night:  'rgba(5,10,40,0.56)',
};
const RAIN_DIMMING = 'rgba(40,60,80,0.16)';
const FIREFLY_COUNT = 24;

/** Five times of day that follow the clock, the system appearance, or a fixed choice. */
export function currentPhase(settings, date) {
  if (settings.theme === 'system') return settings.systemDark ? 'night' : 'day';
  if (settings.theme !== 'time') return settings.theme;
  const hour = date.getHours() + date.getMinutes() / 60;
  if (hour >= 5 && hour < 7) return 'dawn';
  if (hour >= 7 && hour < 17) return 'day';
  if (hour >= 17 && hour < 19) return 'golden';
  if (hour >= 19 && hour < 20.5) return 'dusk';
  return 'night';
}

export function drawSky(world, phase, raining, time) {
  fill(TINTS[phase], world.width, world.height);
  if (raining) fill(RAIN_DIMMING, world.width, world.height);
  if (phase === 'night' || phase === 'dusk') drawFireflies(world, time);
  else world.fireflies.length = 0;
}

function drawFireflies(world, time) {
  while (world.fireflies.length < FIREFLY_COUNT) {
    world.fireflies.push({ x: random(0, world.width), y: random(0, world.height), phase: random(0, 6.28), vx: random(-0.3, 0.3), vy: random(-0.3, 0.3) });
  }
  for (const fly of world.fireflies) {
    fly.x = (fly.x + fly.vx + world.width) % world.width;
    fly.y = (fly.y + fly.vy + Math.sin(time + fly.phase) * 0.15 + world.height) % world.height;
    const glow = (Math.sin(time * 2 + fly.phase) + 1) / 2;
    disc(fly.x, fly.y, 3, `rgba(240,255,140,${glow * 0.18})`);
    rect(fly.x, fly.y, 2, 2, `rgba(250,255,170,${glow})`);
  }
}
