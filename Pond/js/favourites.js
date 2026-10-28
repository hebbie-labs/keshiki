import { jitter, pick, random } from './math.js';
import { randomLeaf } from './duckweed.js';
import { behindGoose } from './goose.js';

export const FAVOURITES = ['tiny fish', 'duckweed', 'lotus shade', 'the frog', 'the ball', 'the goose'];

/**
 * Where a koi goes to enjoy its favourite thing, or null if that thing isn't around.
 * Moving favourites carry `track`, so the koi keeps following them.
 */
export function favouriteTarget(koi, world) {
  switch (koi.favourite) {
    case 'tiny fish': return tracking(() => world.school.center);
    case 'duckweed': { const leaf = randomLeaf(world); return leaf && favourite(leaf); }
    case 'lotus shade': { const pad = pick(world.pads); return favourite(jitter(pad, pad.radius * 0.6)); }
    case 'the frog': return favourite(nearPadEdge(world.frog.pad));
    case 'the ball': return world.ball && tracking(() => world.ball);
    case 'the goose': return world.goose && tracking(() => world.goose && behindGoose(world.goose));
    default: return null;
  }
}

const favourite = point => ({ x: point.x, y: point.y, favourite: true });

const tracking = locate => ({ ...favourite(locate()), track: locate });

function nearPadEdge(pad) {
  const angle = random(0, Math.PI * 2);
  return { x: pad.x + Math.cos(angle) * (pad.radius + 10), y: pad.y + Math.sin(angle) * (pad.radius + 10) };
}
