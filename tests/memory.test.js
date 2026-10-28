import { test } from 'node:test';
import assert from 'node:assert/strict';
import { claimDailyGreeting, createMemory, recordFeeding, usualSpot } from '../Pond/js/memory.js';

const at = (day, hour, minute) => new Date(2026, 9, day, hour, minute);

test('a routine needs feedings on two different days', () => {
  const memory = createMemory();
  recordFeeding(memory, { x: 0.2, y: 0.4 }, at(1, 8, 30));
  recordFeeding(memory, { x: 0.2, y: 0.4 }, at(1, 8, 35));
  assert.equal(usualSpot(memory, at(2, 8, 30)), null);

  recordFeeding(memory, { x: 0.4, y: 0.6 }, at(2, 8, 25));
  const spot = usualSpot(memory, at(3, 8, 40));
  assert.ok(Math.abs(spot.x - 0.2667) < 0.001);
  assert.ok(Math.abs(spot.y - 0.4667) < 0.001);
});

test('feedings at other times of day are ignored', () => {
  const memory = createMemory();
  recordFeeding(memory, { x: 0.2, y: 0.2 }, at(1, 8, 30));
  recordFeeding(memory, { x: 0.2, y: 0.2 }, at(2, 8, 30));
  assert.equal(usualSpot(memory, at(3, 12, 0)), null);
});

test('routines wrap around midnight', () => {
  const memory = createMemory();
  recordFeeding(memory, { x: 0.5, y: 0.5 }, at(1, 23, 55));
  recordFeeding(memory, { x: 0.5, y: 0.5 }, at(2, 23, 50));
  assert.deepEqual(usualSpot(memory, at(3, 0, 5)), { x: 0.5, y: 0.5 });
});

test('only the most recent feedings are remembered', () => {
  const memory = createMemory();
  for (let i = 0; i < 100; i++) recordFeeding(memory, { x: 0, y: 0 }, at(1, 8, 0));
  assert.equal(memory.feedings.length, 60);
});

test('the koi greet once per day', () => {
  const memory = createMemory();
  assert.equal(claimDailyGreeting(memory, at(1, 9, 0)), true);
  assert.equal(claimDailyGreeting(memory, at(1, 18, 0)), false);
  assert.equal(claimDailyGreeting(memory, at(2, 7, 0)), true);
});
