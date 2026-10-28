import { clamp, distance, randomPointIn } from './math.js';
import { SHADOW, disc, rect } from './pixel.js';
import { addRipple } from './ripples.js';

const RADIUS = 8;
const NUDGE_REACH = 14;
const FRICTION = 0.985;
const BOUNCE = 0.8;
const THREAD_COLORS = ['#d9443a', '#3a6fd9', '#e8b730'];

/** A temari ball floating on the water that the koi (and the goose) push around. */
export function dropBall(world) {
  const { x, y } = randomPointIn(world, 120, 100);
  world.ball = { x, y, vx: 0, vy: 0, spin: 0 };
  for (let i = 0; i < 3; i++) addRipple(world, x, y, 2 + i * 4);
}

/** Pushes the ball along the koi's heading; true if the koi touched it. */
export function nudgeBall(ball, koi) {
  if (!ball || distance(ball, koi.body[0]) >= NUDGE_REACH) return false;
  ball.vx += Math.cos(koi.heading) * koi.velocity * 1.2;
  ball.vy += Math.sin(koi.heading) * koi.velocity * 1.2;
  return true;
}

export function updateBall(world, dt) {
  const ball = world.ball;
  if (!ball) return;
  ball.x += ball.vx * dt * 60;
  ball.y += ball.vy * dt * 60;
  bounceOffEdges(ball, world);
  if (world.goose && distance(world.goose, ball) < 18) {
    ball.vx += (ball.x - world.goose.x) * 0.02;
    ball.vy += (ball.y - world.goose.y) * 0.02;
  }
  ball.vx *= FRICTION;
  ball.vy *= FRICTION;
  ball.spin += Math.hypot(ball.vx, ball.vy) * dt * 0.4;
}

export function drawBall(ball) {
  if (!ball) return;
  disc(ball.x + 4, ball.y + 5, RADIUS, SHADOW);
  disc(ball.x, ball.y, RADIUS, '#f3ede0');
  for (let thread = 0; thread < 6; thread++) {
    const angle = ball.spin + thread / 6 * Math.PI * 2;
    for (let r = 1; r < RADIUS; r++) {
      rect(ball.x + Math.cos(angle + r * 0.12) * r, ball.y + Math.sin(angle + r * 0.12) * r, 1, 1, THREAD_COLORS[thread % 3]);
    }
  }
  disc(ball.x, ball.y, 2, THREAD_COLORS[0]);
  rect(ball.x - 4, ball.y - 5, 2, 1, 'rgba(255,255,255,0.6)');
}

function bounceOffEdges(ball, world) {
  if (ball.x < 10 || ball.x > world.width - 10) {
    ball.vx *= -BOUNCE;
    ball.x = clamp(ball.x, 10, world.width - 10);
  }
  if (ball.y < 10 || ball.y > world.height - 10) {
    ball.vy *= -BOUNCE;
    ball.y = clamp(ball.y, 10, world.height - 10);
  }
}
