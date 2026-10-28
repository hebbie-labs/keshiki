// Pixel-exact drawing helpers. Everything is drawn with fillRect so nothing gets anti-aliased.

export const SHADOW = 'rgba(0,20,10,0.3)';

const HEART = ['.X.X.', 'XXXXX', 'XXXXX', '.XXX.', '..X..'];

let context;

export function useContext(canvasContext) {
  context = canvasContext;
  context.imageSmoothingEnabled = false;
}

export function rect(x, y, width, height, color) {
  context.fillStyle = color;
  context.fillRect(Math.round(x), Math.round(y), width, height);
}

export function disc(x, y, radius, color) {
  context.fillStyle = color;
  const cx = Math.round(x), cy = Math.round(y);
  const reach = Math.ceil(radius), radiusSquared = radius * radius;
  for (let dy = -reach; dy <= reach; dy++) {
    if (dy * dy > radiusSquared) continue;
    const halfWidth = Math.floor(Math.sqrt(radiusSquared - dy * dy));
    context.fillRect(cx - halfWidth, cy + dy, halfWidth * 2 + 1, 1);
  }
}

/** A dotted ellipse, squashed vertically so ripples look like they lie on the water. */
export function ring(x, y, radius, color, squash = 0.7) {
  context.fillStyle = color;
  const dots = Math.max(10, Math.round(radius * 5));
  for (let i = 0; i < dots; i++) {
    const angle = i / dots * Math.PI * 2;
    context.fillRect(Math.round(x + Math.cos(angle) * radius), Math.round(y + Math.sin(angle) * radius * squash), 1, 1);
  }
}

export function heart(x, y, opacity) {
  context.fillStyle = `rgba(240,90,110,${opacity})`;
  HEART.forEach((row, line) => [...row].forEach((cell, column) => {
    if (cell === 'X') context.fillRect(Math.round(x) + (column - 2) * 2, Math.round(y) + line * 2, 2, 2);
  }));
}

export function fill(color, width, height) {
  context.fillStyle = color;
  context.fillRect(0, 0, width, height);
}

export function drawImage(image) {
  context.drawImage(image, 0, 0);
}
