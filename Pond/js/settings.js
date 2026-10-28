export const settings = {
  theme: 'time',       // time | system | dawn | day | golden | dusk | night
  water: 'pond',       // pond | deep-clear
  mood: 'calm',        // calm | playful
  rain: false,
  paused: false,
  systemDark: false,
  callOnClick: true,
  feedOnAlt: true,
};

/** Lets the page be previewed in a browser, e.g. index.html?theme=night&rain=1 */
export function applyQueryString(search) {
  for (const [key, value] of new URLSearchParams(search)) {
    settings[key] = value === '1' ? true : value === '0' ? false : value;
  }
}

/** Applies changes and reports whether the water has to be repainted. */
export function updateSettings(changes) {
  const previousWater = settings.water;
  Object.assign(settings, changes);
  return settings.water !== previousWater;
}
