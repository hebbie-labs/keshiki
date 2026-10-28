const FADE_IN_DELAY_MS = 2500;
const FADE_OUT_DELAY_MS = 9000;
const LABEL_LIFT = 40;

/** Shows "good morning" above the spot where the koi gather. */
export function showGreeting(label, spot, world) {
  label.textContent = 'good morning';
  label.style.left = `${spot.x / world.width * 100}vw`;
  label.style.top = `${(spot.y - LABEL_LIFT) / world.height * 100}vh`;
  setTimeout(() => label.classList.add('visible'), FADE_IN_DELAY_MS);
  setTimeout(() => label.classList.remove('visible'), FADE_OUT_DELAY_MS);
}
