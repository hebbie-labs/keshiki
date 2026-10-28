import { applyQueryString, settings, updateSettings } from './settings.js';
import { useContext, drawImage } from './pixel.js';
import { paintWater } from './water.js';
import { createWorld, drawWorld, inviteVisitor, updateWorld } from './world.js';
import { callKoi } from './koi.js';
import { dropFood } from './food.js';
import { addRipple } from './ripples.js';
import { currentPhase } from './sky.js';
import { claimDailyGreeting, lastFeedingSpot, loadMemory, recordFeeding, saveMemory, usualSpot } from './memory.js';
import { showGreeting } from './greeting.js';

// The pond is drawn 960px wide (height follows the screen) and scaled up with crisp pixels.
const POND_WIDTH = 960;
const MAX_FRAME_SECONDS = 0.05;
const ROUTINE_CHECK_SECONDS = 30;
const GREETING_SECONDS = 12;

const canvas = document.getElementById('pond');
const greetingLabel = document.getElementById('greeting');
const context = canvas.getContext('2d');

updateSettings(window.__settings ?? {});
applyQueryString(location.search);
const memory = loadMemory();
const world = createWorld(POND_WIDTH, viewportHeight());
let water = resizeCanvas();
let lastFrame = performance.now();
let nextRoutineCheck = 0;

canvas.addEventListener('pointerdown', event => touchWater(toPondPoint(event.clientX, event.clientY), event.altKey));
addEventListener('resize', onResize);
requestAnimationFrame(frame);

/** Called by the macOS app, which receives desktop clicks on the pond's behalf. */
window.pond = {
  set(changes) { if (updateSettings(changes)) water = paintWater(world.width, world.height, settings.water); },
  click(clientX, clientY, withFood) { touchWater(toPondPoint(clientX, clientY), withFood); },
  visit(visitor) { inviteVisitor(world, visitor); },
};

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(MAX_FRAME_SECONDS, (now - lastFrame) / 1000);
  lastFrame = now;
  if (settings.paused || document.hidden) return;

  const time = now / 1000;
  if (time > nextRoutineCheck) checkRoutine(time);
  if (world.greeting && time > world.greeting.until) endGreeting();
  updateWorld(world, dt);
  drawImage(water);
  drawWorld(world, time, currentPhase(settings, new Date()));
}

function touchWater(point, withFood) {
  if (withFood) {
    if (settings.feedOnAlt) feed(point);
    return;
  }
  addRipple(world, point.x, point.y);
  if (settings.callOnClick) world.kois.forEach(koi => callKoi(koi, point));
}

function feed(point) {
  dropFood(world, point);
  recordFeeding(memory, { x: point.x / world.width, y: point.y / world.height }, new Date());
  saveMemory(memory);
}

function checkRoutine(time) {
  nextRoutineCheck = time + ROUTINE_CHECK_SECONDS;
  world.usualSpot = toPondSpot(usualSpot(memory, new Date()));
  if (claimDailyGreeting(memory, new Date())) greet(time);
}

/** The first time you see the pond each day, the koi gather at your spot to say hello. */
function greet(time) {
  saveMemory(memory);
  const spot = world.usualSpot ?? toPondSpot(lastFeedingSpot(memory)) ?? { x: world.width / 2, y: world.height / 2 };
  world.greeting = { ...spot, until: time + GREETING_SECONDS };
  world.kois.forEach(koi => { koi.wanderTimer = 0; });
  showGreeting(greetingLabel, spot, world);
}

function endGreeting() {
  world.greeting = null;
  world.kois.forEach(koi => { koi.wanderTimer = 0; });
}

function onResize() {
  const height = viewportHeight();
  if (height === world.height) return;
  world.height = height;
  water = resizeCanvas();
}

function resizeCanvas() {
  canvas.width = world.width;
  canvas.height = world.height;
  useContext(context);
  return paintWater(world.width, world.height, settings.water);
}

function viewportHeight() {
  return Math.round(POND_WIDTH * innerHeight / innerWidth) || 540;
}

function toPondPoint(clientX, clientY) {
  return { x: clientX / innerWidth * world.width, y: clientY / innerHeight * world.height };
}

function toPondSpot(normalised) {
  return normalised && { x: normalised.x * world.width, y: normalised.y * world.height };
}
