export const random = (min, max) => min + Math.random() * (max - min);

export const pick = items => items[Math.floor(Math.random() * items.length)];

export const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

/** Signed shortest turn from one angle to another, in -π..π. */
export const angleDifference = (from, to) => ((to - from + Math.PI * 3) % (Math.PI * 2)) - Math.PI;

export const jitter = (point, spreadX, spreadY = spreadX) =>
  ({ x: point.x + random(-spreadX, spreadX), y: point.y + random(-spreadY, spreadY) });

export const randomPointIn = (area, marginX, marginY = marginX) =>
  ({ x: random(marginX, area.width - marginX), y: random(marginY, area.height - marginY) });
