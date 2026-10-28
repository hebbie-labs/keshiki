import { test } from 'node:test';
import assert from 'node:assert/strict';
import { currentPhase } from '../Pond/js/sky.js';

const at = (hour, minute = 0) => new Date(2026, 9, 28, hour, minute);
const byTime = { theme: 'time' };

test('the time of day follows the clock', () => {
  assert.equal(currentPhase(byTime, at(6)), 'dawn');
  assert.equal(currentPhase(byTime, at(12)), 'day');
  assert.equal(currentPhase(byTime, at(18)), 'golden');
  assert.equal(currentPhase(byTime, at(20)), 'dusk');
  assert.equal(currentPhase(byTime, at(20, 30)), 'night');
  assert.equal(currentPhase(byTime, at(3)), 'night');
});

test('system sync maps dark mode to night', () => {
  assert.equal(currentPhase({ theme: 'system', systemDark: true }, at(12)), 'night');
  assert.equal(currentPhase({ theme: 'system', systemDark: false }, at(23)), 'day');
});

test('a fixed theme ignores the clock', () => {
  assert.equal(currentPhase({ theme: 'golden' }, at(3)), 'golden');
});
