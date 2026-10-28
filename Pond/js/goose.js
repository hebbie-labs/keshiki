import { angleDifference, clamp, distance, pick, random, randomPointIn } from './math.js';
import { disc, rect } from './pixel.js';
import { addRipple } from './ripples.js';

const SCALE = 1.6;
const SPEED = 0.6;
const TURN_RATE = 0.02;
const VISIT_SECONDS = [60, 120];
const PADDLE_EVERY_SECONDS = 0.6;
const WHITE = '#f6f4ee';

/** The goose swims in from an edge, potters around for a while, then leaves again. */
export function inviteGoose(world) {
  if (world.goose) return;
  const entry = pointOffEdge(world);
  world.goose = {
    ...entry,
    heading: Math.atan2(world.height / 2 - entry.y, world.width / 2 - entry.x),
    staysFor: random(...VISIT_SECONDS),
    leaving: false,
    destination: randomPointIn(world, 100, 80),
    paddleTimer: 0,
  };
}

export function sendGooseAway(goose) {
  if (goose) goose.staysFor = 0;
}

export function updateGoose(world, dt) {
  const goose = world.goose;
  if (!goose) return;
  goose.staysFor -= dt;
  chooseDestination(goose, world);
  goose.heading += clamp(angleDifference(goose.heading, Math.atan2(goose.destination.y - goose.y, goose.destination.x - goose.x)), -TURN_RATE, TURN_RATE) * dt * 60;
  goose.x += Math.cos(goose.heading) * SPEED * dt * 60;
  goose.y += Math.sin(goose.heading) * SPEED * dt * 60;
  paddle(goose, world, dt);
  if (goose.leaving && isOffscreen(goose, world)) world.goose = null;
}

/** A spot just behind the goose, for koi that like to follow it. */
export const behindGoose = goose => ({ x: goose.x - Math.cos(goose.heading) * 30, y: goose.y - Math.sin(goose.heading) * 30 });

export function drawGoose(goose, time) {
  if (!goose) return;
  const along = { x: Math.cos(goose.heading) * SCALE, y: Math.sin(goose.heading) * SCALE };
  drawBody(goose, along);
  drawNeckAndHead(goose, along, Math.sin(time * 1.3) * 0.25);
}

function chooseDestination(goose, world) {
  if (goose.staysFor <= 0 && !goose.leaving) {
    goose.leaving = true;
    goose.destination = pointOffEdge(world);
  }
  if (!goose.leaving && distance(goose, goose.destination) < 15) goose.destination = randomPointIn(world, 100, 80);
}

function paddle(goose, world, dt) {
  goose.paddleTimer += dt;
  if (goose.paddleTimer < PADDLE_EVERY_SECONDS) return;
  goose.paddleTimer = 0;
  addRipple(world, goose.x - Math.cos(goose.heading) * 14, goose.y - Math.sin(goose.heading) * 14, 3, 0.6);
}

function drawBody({ x, y }, along) {
  for (let i = -3; i <= 3; i++) disc(x + along.x * i * 3 + 8, y + along.y * i * 3 + 11, 16 - Math.abs(i) * 1.6, 'rgba(0,20,10,0.3)');
  for (let i = -4; i <= 3; i++) disc(x + along.x * i * 3, y + along.y * i * 3, 16 - Math.abs(i) * 1.3, i < -2 ? '#d9d6cc' : WHITE);
  for (const side of [-1, 1]) {
    for (let i = -2; i <= 2; i++) disc(x + along.x * i * 3 - along.y * side * 6, y + along.y * i * 3 + along.x * side * 6, 6, '#e3e0d6');
  }
}

function drawNeckAndHead(goose, along, bend) {
  const neckAngle = goose.heading + bend;
  const step = { x: Math.cos(neckAngle) * SCALE, y: Math.sin(neckAngle) * SCALE };
  let x = goose.x + along.x * 10, y = goose.y + along.y * 10;
  for (let i = 0; i < 5; i++) {
    x += step.x * 3;
    y += step.y * 3;
    disc(x, y, 4, WHITE);
  }
  disc(x, y, 6, WHITE);
  disc(x + step.x * 5, y + step.y * 5, 3, '#f08a24');
  for (const side of [-1, 1]) rect(x + Math.cos(neckAngle + side * 1.3) * 4, y + Math.sin(neckAngle + side * 1.3) * 4, 2, 2, '#111');
}

function pointOffEdge(world) {
  return pick([
    { x: -30, y: random(60, world.height - 60) },
    { x: world.width + 30, y: random(60, world.height - 60) },
    { x: random(60, world.width - 60), y: -30 },
    { x: random(60, world.width - 60), y: world.height + 30 },
  ]);
}

const isOffscreen = (point, world) => point.x < -40 || point.x > world.width + 40 || point.y < -40 || point.y > world.height + 40;
