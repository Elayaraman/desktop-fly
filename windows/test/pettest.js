import assert from 'node:assert/strict';
import { PetBehavior } from '../src/pet.js';
import { Fly } from '../src/flymodel.js';
import { makeSignals, LIFSim } from '../src/sim.js';
import { SignalBuilder } from '../src/signals.js';
import { loadBrainData } from '../src/data.js';
import { resetRandom } from './random.js';
const bounds = { width: 1280, height: 800 }, dt = 1 / 120;
function check(name, passed) { assert.ok(passed, name); console.log(`PASS ${name}`); }
function pair() {
  resetRandom('pet-tests');
  const fly = new Fly({ x: -240, y: 0 }); fly.heading = 0; fly.state = 'idle';
  return [new PetBehavior(), fly];
}
function run(pet, fly, ticks, mouse, s = makeSignals()) {
  for (let i = 0; i < ticks; i++) {
    const intent = pet.step(dt, fly, mouse, 0, s);
    fly.update(dt, bounds, mouse, s, intent);
  }
}
{
  const [pet, fly] = pair(), mouse = { x: 300, y: 0 };
  run(pet, fly, 1200, mouse);
  const d = Math.hypot(mouse.x - fly.pos.x, mouse.y - fly.pos.y);
  check('gentle cursor is approached and respected at 150pt', d > 140 && d <= 151);
  pet.followCursor = false;
  check('follow off yields control to neural behavior', pet.step(dt, fly, mouse, 0, makeSignals()) === null);
  pet.followCursor = true;
  check('fast cursor is not pursued', pet.step(dt, fly, mouse, 800, makeSignals()) === null);
  check('stationary cursor is friendly; fast cursor remains a threat',
    pet.gentleCursor(0, 20) && !pet.gentleCursor(900, 100));
}
{
  const [pet, fly] = pair(); pet.dropSugar({ x: 80, y: 0 }, bounds);
  run(pet, fly, 120, { x: -400, y: 0 });
  check('sugar takes priority and is not consumed at a distance', fly.pos.x > -240 && pet.sugar[0].remaining === 1);
  run(pet, fly, 1200, null);
  check('fly reaches sugar and finishes exactly one portion', !pet.sugar.length && pet.meals === 1);
  check('feeding finishes near the sugar, without teleportation', Math.hypot(fly.pos.x - 80, fly.pos.y) < 23);
}
{
  const [pet, fly] = pair(); pet.dropSugar(fly.pos, bounds);
  run(pet, fly, 60, null);
  const remaining = pet.sugar[0].remaining;
  run(pet, fly, 1, { x: -200, y: 0 }, { ...makeSignals(), escape: true });
  check('escape interrupts feeding immediately', fly.state === 'flying' && pet.sugar[0].remaining === remaining);
  run(pet, fly, 10, null);
  check('food is not consumed in flight', pet.sugar[0].remaining === remaining);
  fly.state = 'idle'; fly.scareCooldown = 0;
  run(pet, fly, 10, null, { ...makeSignals(), sleep: true });
  check('sleep also interrupts feeding', fly.state === 'sleeping' && pet.sugar[0].remaining === remaining);
}
{
  const [pet, fly] = pair();
  for (let i = 0; i < 9; i++) pet.dropSugar({ x: 9000, y: -9000 }, bounds);
  check('food is bounded to five visible drops', pet.sugar.length === 5
    && pet.sugar.every(d => d.position.x <= 570 && d.position.y >= -330));
  pet.dropSugar({ x: NaN, y: 0 }, bounds);
  check('invalid coordinates cannot corrupt food state', pet.sugar.length === 5);
  pet.step(180, fly, null, 0, makeSignals());
  check('old food expires', !pet.sugar.length);
  pet.dropSugar({ x: 0, y: 0 }, bounds); pet.clearSugar();
  check('clear removes all food', !pet.sugar.length);
}
{
  const [pet, fly] = pair(), data = loadBrainData();
  assert.ok(data);
  const sim = new LIFSim(data.circuit, null, data.locomotor), builder = new SignalBuilder();
  let ms = 0;
  pet.dropSugar({ x: 0, y: 0 }, bounds);
  for (let i = 0; i < 1440; i++) {
    sim.legFeedback = fly.legFeedback;
    ms += dt * 1000; const steps = Math.floor(ms + 1e-6); ms -= steps;
    sim.step(steps);
    const s = builder.make(sim, dt), intent = pet.step(dt, fly, null, 0, s);
    fly.update(dt, bounds, null, s, intent);
  }
  check('feeding completes while the real circuits continue running', pet.meals === 1 && sim.ratePop > 0);
}
console.log('ALL PET TESTS PASS');
