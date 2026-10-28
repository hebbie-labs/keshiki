// What the koi remember: where and when you feed them, and when they last said good morning.

const STORAGE_KEY = 'pond';
const MINUTES_PER_DAY = 24 * 60;
const ROUTINE_WINDOW_MINUTES = 20;
const DAYS_TO_LEARN_ROUTINE = 2;
const FEEDINGS_REMEMBERED = 60;

export const minuteOfDay = date => date.getHours() * 60 + date.getMinutes();

export function createMemory(saved = {}) {
  return { feedings: saved.feedings ?? [], lastGreetingDay: saved.lastGreetingDay ?? '' };
}

/** `spot` is normalised (0..1) so it survives different screen sizes. */
export function recordFeeding(memory, spot, date) {
  const feeding = { x: spot.x, y: spot.y, minute: minuteOfDay(date), day: date.toDateString() };
  memory.feedings = [...memory.feedings, feeding].slice(-FEEDINGS_REMEMBERED);
}

/** Where you usually feed them around this time of day, once seen on at least two different days. */
export function usualSpot(memory, date) {
  const now = minuteOfDay(date);
  const nearby = memory.feedings.filter(f => minutesApart(f.minute, now) <= ROUTINE_WINDOW_MINUTES);
  if (new Set(nearby.map(f => f.day)).size < DAYS_TO_LEARN_ROUTINE) return null;
  return {
    x: nearby.reduce((sum, f) => sum + f.x, 0) / nearby.length,
    y: nearby.reduce((sum, f) => sum + f.y, 0) / nearby.length,
  };
}

export function lastFeedingSpot(memory) {
  return memory.feedings.at(-1) ?? null;
}

/** True only for the first call on each calendar day. */
export function claimDailyGreeting(memory, date) {
  const day = date.toDateString();
  if (memory.lastGreetingDay === day) return false;
  memory.lastGreetingDay = day;
  return true;
}

/** The macOS app injects `window.__memory`; in a plain browser we fall back to localStorage. */
export function loadMemory() {
  try {
    return createMemory(window.__memory ?? JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}'));
  } catch {
    return createMemory();
  }
}

export function saveMemory(memory) {
  const json = JSON.stringify(memory);
  const host = window.webkit?.messageHandlers?.save;
  if (host) return host.postMessage(json);
  try { localStorage.setItem(STORAGE_KEY, json); } catch { /* private mode: forget quietly */ }
}

function minutesApart(a, b) {
  const difference = Math.abs(a - b) % MINUTES_PER_DAY;
  return Math.min(difference, MINUTES_PER_DAY - difference);
}
