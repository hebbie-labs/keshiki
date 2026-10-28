import { angleDifference, clamp, distance, jitter, pick, random, randomPointIn } from './math.js';
import { disc, heart, rect } from './pixel.js';
import { settings } from './settings.js';
import { eatFoodNear, nearestFood } from './food.js';
import { grazeDuckweed } from './duckweed.js';
import { nudgeBall } from './ball.js';
import { FAVOURITES, favouriteTarget } from './favourites.js';

const SEGMENTS = 12;
const SEGMENT_LENGTH = 5;
const BODY_WIDTHS = [4.6, 6.6, 7.4, 7.4, 6.8, 6.0, 5.0, 4.0, 3.0, 2.3, 1.7, 1.3];
const VARIETIES = [
  { name: 'kohaku',   base: '#f4f1ea', patches: ['#e0542a', '#d9441f'] },
  { name: 'sanke',    base: '#f4f1ea', patches: ['#e0542a', '#1d1d1d'] },
  { name: 'ochiba',   base: '#d9c7a4', patches: ['#f39a2b', '#9a8a70'] },
  { name: 'yamabuki', base: '#f6d36b', patches: ['#fbe7a0'] },
  { name: 'showa',    base: '#1d1d1d', patches: ['#e0542a', '#f4f1ea'] },
  { name: 'platinum', base: '#ecebe4', patches: ['#ffffff'] },
  { name: 'tancho',   base: '#f4f1ea', patches: [], crown: '#e0542a' },
  { name: 'chagoi',   base: '#b06a2c', patches: ['#c98a4a'] },
];
const MOODS = {
  calm:    { speed: 0.75, turn: 1,   wanderSeconds: [6, 14] },
  playful: { speed: 1.45, turn: 1.5, wanderSeconds: [2, 5] },
};
const FOOD_SIGHT = 420;
const CALL_RADIUS = 380;
const GOOSE_FEAR_RADIUS = 90;
const PERSONAL_SPACE = 18;
const HEART_SECONDS = 2.2;
const SHADOW_OFFSET = { x: 6, y: 8 };
const SHADOW = 'rgba(0,15,8,0.28)';
const FIN = 'rgba(250,240,230,0.5)';

export function createKoi(world, index) {
  const variety = VARIETIES[index % VARIETIES.length];
  const start = randomPointIn(world, 120, 80);
  return {
    body: Array.from({ length: SEGMENTS }, (_, i) => ({ x: start.x - i * SEGMENT_LENGTH, y: start.y })),
    heading: 0, velocity: 0, size: random(0.85, 1.3),
    variety, patches: paintPatches(variety),
    speed: random(0.9, 1.15), turnRate: random(0.035, 0.06),
    target: null, wanderTimer: 0, tailPhase: random(0, 6.28), excitement: 0,
    favourite: FAVOURITES[index % FAVOURITES.length], heartTimer: 0, heartCooldown: random(5, 20),
  };
}

export function updateKoi(koi, world, dt) {
  chooseTarget(koi, world, dt);
  swimTowards(koi, steeringPoint(koi, world), world, dt);
  interactWithSurroundings(koi, world);
  followHead(koi);
  koi.heartTimer = Math.max(0, koi.heartTimer - dt);
  koi.heartCooldown -= dt;
}

/** A click on the water: nearby koi come over to see. */
export function callKoi(koi, point) {
  if (distance(koi.body[0], point) >= CALL_RADIUS) return;
  koi.target = jitter(point, 15);
  koi.wanderTimer = random(3, 6);
  koi.excitement = 0.6;
}

export function drawKoiShadow(koi) {
  const outline = bodyOutline(koi, SHADOW_OFFSET);
  drawFins(koi, outline, SHADOW);
  drawBody(koi, outline, SHADOW);
}

export function drawKoi(koi) {
  const outline = bodyOutline(koi, { x: 0, y: 0 });
  drawFins(koi, outline, FIN);
  drawBody(koi, outline, koi.variety.base);
  drawPatches(koi, outline);
  drawFace(koi, outline);
  if (koi.heartTimer > 0) heart(outline[0].x, outline[0].y - 18 - (HEART_SECONDS - koi.heartTimer) * 6, Math.min(1, koi.heartTimer));
}

// ---- behaviour ----

function chooseTarget(koi, world, dt) {
  const mood = currentMood();
  koi.wanderTimer -= dt;
  koi.excitement = Math.max(0, koi.excitement - dt * 0.2);

  const food = nearestFood(world, koi.body[0], FOOD_SIGHT);
  if (food) {
    koi.target = food;
    koi.excitement = 1;
  } else if (world.greeting) {
    if (koi.wanderTimer > 0) return;
    koi.target = jitter(world.greeting, 35, 25);
    koi.wanderTimer = random(2, 4);
  } else if (!koi.target || koi.wanderTimer <= 0 || distance(koi.target, koi.body[0]) < 10) {
    koi.target = wanderTarget(koi, world);
    koi.wanderTimer = random(...mood.wanderSeconds);
  } else if (koi.target.track) {
    const position = koi.target.track();
    if (position) Object.assign(koi.target, { x: position.x, y: position.y });
  }
}

function wanderTarget(koi, world) {
  if (world.usualSpot && Math.random() < 0.6) return jitter(world.usualSpot, 40, 30);
  if (settings.mood === 'playful' && world.ball && Math.random() < 0.3) return { x: world.ball.x, y: world.ball.y };
  if (Math.random() < 0.55) {
    const favourite = favouriteTarget(koi, world);
    if (favourite) return favourite;
  }
  return randomPointIn(world, 40);
}

/** The target, adjusted for fear of the goose and a little personal space. */
function steeringPoint(koi, world) {
  const head = koi.body[0];
  const goose = world.goose;
  if (goose && koi.favourite !== 'the goose' && distance(goose, head) < GOOSE_FEAR_RADIUS) {
    koi.excitement = 0.8;
    return { x: head.x + (head.x - goose.x) * 2, y: head.y + (head.y - goose.y) * 2 };
  }
  const point = { x: clamp(koi.target.x, 25, world.width - 25), y: clamp(koi.target.y, 25, world.height - 25) };
  for (const other of world.kois) {
    if (other === koi || distance(other.body[0], head) >= PERSONAL_SPACE) continue;
    point.x += head.x - other.body[0].x;
    point.y += head.y - other.body[0].y;
  }
  return point;
}

function swimTowards(koi, point, world, dt) {
  const mood = currentMood();
  const head = koi.body[0];
  const maxTurn = koi.turnRate * mood.turn;
  const desiredHeading = Math.atan2(point.y - head.y, point.x - head.x);
  koi.heading += clamp(angleDifference(koi.heading, desiredHeading), -maxTurn, maxTurn) * (1 + koi.excitement) * dt * 60;

  const slowDownNearTarget = Math.min(1, distance(point, head) / 60 + 0.25);
  const topSpeed = koi.speed * mood.speed * (1 + koi.excitement * 1.4) * slowDownNearTarget;
  koi.velocity += (topSpeed - koi.velocity) * 0.04;
  koi.tailPhase += dt * (3 + koi.velocity * 4);
  head.x = clamp(head.x + Math.cos(koi.heading) * koi.velocity * dt * 60, 5, world.width - 5);
  head.y = clamp(head.y + Math.sin(koi.heading) * koi.velocity * dt * 60, 5, world.height - 5);
}

function interactWithSurroundings(koi, world) {
  const head = koi.body[0];
  eatFoodNear(world, head, 7 * koi.size);
  const grazed = grazeDuckweed(world, head, 6 * koi.size);
  const playedWithBall = nudgeBall(world.ball, koi);
  const atFavourite = koi.target?.favourite && distance(koi.target, head) < 30;
  if (atFavourite || (grazed && koi.favourite === 'duckweed') || (playedWithBall && koi.favourite === 'the ball')) feelHappy(koi);
}

function feelHappy(koi) {
  if (koi.heartCooldown > 0) return;
  koi.heartTimer = HEART_SECONDS;
  koi.heartCooldown = random(18, 40);
}

/** The body trails the head like a rope of fixed-length segments. */
function followHead(koi) {
  const length = SEGMENT_LENGTH * koi.size;
  for (let i = 1; i < SEGMENTS; i++) {
    const leader = koi.body[i - 1], segment = koi.body[i];
    let dx = segment.x - leader.x, dy = segment.y - leader.y;
    if (!dx && !dy) { dx = -Math.cos(koi.heading); dy = -Math.sin(koi.heading); }
    const gap = Math.hypot(dx, dy);
    segment.x = leader.x + dx / gap * length;
    segment.y = leader.y + dy / gap * length;
  }
}

const currentMood = () => MOODS[settings.mood] ?? MOODS.calm;

/** Runs of colour along the body, so patches look like patches rather than stripes. */
function paintPatches(variety) {
  let current = null;
  return Array.from({ length: SEGMENTS }, (_, i) => {
    if (i > 0 && Math.random() < 0.35) {
      current = variety.patches.length && Math.random() < 0.65 ? { color: pick(variety.patches), side: random(-0.6, 0.6) } : null;
    }
    return current;
  });
}

// ---- drawing ----

/** Segment centres with the swimming wave applied sideways, plus each segment's direction. */
function bodyOutline(koi, offset) {
  return koi.body.map((point, i) => {
    const ahead = koi.body[Math.max(0, i - 1)], behind = koi.body[Math.min(SEGMENTS - 1, i + 1)];
    const direction = Math.atan2(ahead.y - behind.y, ahead.x - behind.x);
    const sway = Math.sin(koi.tailPhase - i * 0.7) * (i / SEGMENTS) * 3 * koi.size;
    return {
      x: point.x + Math.cos(direction + Math.PI / 2) * sway + offset.x,
      y: point.y + Math.sin(direction + Math.PI / 2) * sway + offset.y,
      direction,
    };
  });
}

function drawFins(koi, outline, color) {
  const size = koi.size;
  const shoulder = outline[2], flap = Math.sin(koi.tailPhase * 0.7) * 0.35;
  for (const side of [-1, 1]) {
    const angle = shoulder.direction + side * (2.1 + flap);
    for (let j = 1; j <= 3; j++) {
      disc(shoulder.x + Math.cos(angle) * (4 + j * 2.2) * size, shoulder.y + Math.sin(angle) * (4 + j * 2.2) * size, (3.2 - j * 0.6) * size, color);
    }
  }
  const tail = outline[SEGMENTS - 1];
  for (const side of [-1, 1]) {
    const angle = tail.direction + Math.PI + side * 0.45 + Math.sin(koi.tailPhase) * 0.35;
    for (let j = 1; j <= 3; j++) {
      disc(tail.x + Math.cos(angle) * j * 2.6 * size, tail.y + Math.sin(angle) * j * 2.6 * size, (2 + j * 0.5) * size, color);
    }
  }
}

/** Discs per segment plus one between neighbours, so the thin tail doesn't look dotted. */
function drawBody(koi, outline, color) {
  for (let i = SEGMENTS - 1; i >= 0; i--) {
    disc(outline[i].x, outline[i].y, BODY_WIDTHS[i] * koi.size, color);
    if (i === SEGMENTS - 1) continue;
    const next = outline[i + 1];
    disc((outline[i].x + next.x) / 2, (outline[i].y + next.y) / 2, (BODY_WIDTHS[i] + BODY_WIDTHS[i + 1]) / 2 * koi.size, color);
  }
}

function drawPatches(koi, outline) {
  for (let i = SEGMENTS - 1; i >= 1; i--) {
    const patch = koi.patches[i];
    if (!patch) continue;
    const width = BODY_WIDTHS[i] * koi.size, across = outline[i].direction + Math.PI / 2;
    disc(outline[i].x + Math.cos(across) * patch.side * width * 0.5, outline[i].y + Math.sin(across) * patch.side * width * 0.5, width * 0.72, patch.color);
  }
  if (koi.variety.crown) disc(outline[1].x, outline[1].y, 3 * koi.size, koi.variety.crown);
}

function drawFace(koi, outline) {
  for (let i = 1; i < 8; i++) rect(outline[i].x, outline[i].y, 1, 1, 'rgba(255,255,255,0.18)');
  const head = outline[0];
  for (const side of [-1, 1]) {
    const angle = koi.heading + side * 1.2;
    rect(head.x + Math.cos(angle) * 3.4 * koi.size, head.y + Math.sin(angle) * 3.4 * koi.size, 1, 1, '#111');
  }
}
