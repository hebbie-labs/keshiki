import { clamp, pick, random } from './math.js';
import { rect } from './pixel.js';

const WATERS = {
  pond: {
    deep: [12, 38, 30], shallow: [30, 82, 62],
    pebbles: ['#2d5b4a', '#284f41', '#35664f', '#1f4437', '#3d6b55'], pebbleOpacity: [0.5, 1],
  },
  'deep-clear': {
    deep: [10, 40, 62], shallow: [46, 120, 128],
    pebbles: ['#7d8f86', '#5f746f', '#a39a83', '#4d6466', '#8a7f6a'], pebbleOpacity: [0.4, 0.9],
  },
};
const DEPTH_BANDS = 6;
const PEBBLE_COUNT = 1400;
const CAUSTIC_COUNT = 180;

/** Paints the still parts of the pond once into an offscreen canvas. */
export function paintWater(width, height, waterName) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  const water = WATERS[waterName] ?? WATERS.pond;
  paintDepth(context, width, height, water);
  paintPebbles(context, width, height, water);
  return canvas;
}

/** Light speckles drifting slowly across the bottom. */
export function drawCaustics(world, time) {
  for (let i = 0; i < CAUSTIC_COUNT; i++) {
    const x = (i * 197.3 + time * (4 + i % 7)) % world.width;
    const y = (i * 113.7 + Math.sin(time * 0.5 + i) * 10 + world.height) % world.height;
    rect(x, y, 3 + i % 3, 1, 'rgba(170,235,200,0.08)');
  }
}

function paintDepth(context, width, height, water) {
  const image = context.createImageData(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const band = Math.floor(depthAt(x, y, width, height) * DEPTH_BANDS) / DEPTH_BANDS;
      const offset = (y * width + x) * 4;
      for (let channel = 0; channel < 3; channel++) {
        image.data[offset + channel] = water.shallow[channel] + (water.deep[channel] - water.shallow[channel]) * band;
      }
      image.data[offset + 3] = 255;
    }
  }
  context.putImageData(image, 0, 0);
}

/** 0 = shallow edge, 1 = deep middle, with soft waves and a checkerboard dither. */
function depthAt(x, y, width, height) {
  const cx = (x - width / 2) / (width / 2), cy = (y - height / 2) / (height / 2);
  const bowl = 1 - Math.min(1, cx * cx * 0.5 + cy * cy * 0.7);
  const waves = (Math.sin(x * 0.035 + y * 0.015) + Math.sin(x * 0.011 - y * 0.025) + Math.sin((x + y) * 0.05) * 0.4) * 0.5;
  const dither = ((x >> 1) + (y >> 1)) % 2 ? 0.025 : 0;
  return clamp(bowl * 0.75 + waves * 0.12 + dither, 0, 1);
}

/** Denser toward the edges, like a real pond floor. */
function paintPebbles(context, width, height, water) {
  for (let i = 0; i < PEBBLE_COUNT; i++) {
    const nearEdge = Math.random() < 0.7;
    const x = nearEdge && Math.random() < 0.5 ? pick([random(0, 90), random(width - 90, width)]) : random(0, width);
    const y = nearEdge && Math.random() < 0.5 ? pick([random(0, 60), random(height - 60, height)]) : random(0, height);
    context.globalAlpha = random(...water.pebbleOpacity);
    context.fillStyle = pick(water.pebbles);
    context.fillRect(Math.round(x), Math.round(y), pick([1, 2, 2, 3, 4]), pick([1, 2, 2, 3]));
  }
  context.globalAlpha = 1;
}
