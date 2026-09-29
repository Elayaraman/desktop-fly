// Explicit app rules, mirrored by PetBehavior.swift; not MN9 physiology.
import { clampf } from './util.js';
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
export class PetBehavior {
  constructor() {
    this.followCursor = true; this.sugar = []; this.meals = 0;
    this.status = 'Following cursor'; this.nextID = 0;
  }
  clearSugar() { this.sugar = []; }
  dropSugar(point, bounds) {
    if (!Number.isFinite(point.x) || !Number.isFinite(point.y)) return;
    const hw = Math.max(0, bounds.width / 2 - 70), hh = Math.max(0, bounds.height / 2 - 70);
    if (this.sugar.length >= 5) this.sugar.shift();
    this.sugar.push({ id: this.nextID++, position: {
      x: clampf(point.x, -hw, hw), y: clampf(point.y, -hh, hh),
    }, remaining: 1, age: 0 });
  }
  gentleCursor(speed, d) {
    return (this.followCursor || this.sugar.length > 0) && (speed < 60 || (speed < 350 && d > 80));
  }
  step(dt, fly, mouse, cursorSpeed, s) {
    for (const drop of this.sugar) drop.age += dt;
    this.sugar = this.sugar.filter(d => d.age < 180 && d.remaining > 0);
    if (!s) { this.status = 'Neural data unavailable'; return null; }
    if (fly.state === 'flying' || s.escape || s.nervous >= 0.4 || s.sleep
      || fly.scareCooldown > 0 || fly.dartTimer > 0 || fly.backwardTimer > 0) {
      this.status = s.sleep ? 'Sleeping' : 'Startled / recovering'; return null;
    }
    const nearest = this.sugar.reduce((best, d) => !best
      || distance(d.position, fly.pos) < distance(best.position, fly.pos) ? d : best, null);
    if (nearest) {
      const eating = distance(nearest.position, fly.pos) <= 22;
      if (eating) {
        nearest.remaining = Math.max(0, nearest.remaining - dt / 4);
        if (nearest.remaining <= 0) {
          this.sugar = this.sugar.filter(d => d.id !== nearest.id); this.meals++;
        }
      }
      this.status = eating ? 'Eating sugar' : 'Going to sugar';
      return { target: nearest.position, stopRadius: 22, feeding: eating };
    }
    if (!this.followCursor || !mouse || cursorSpeed >= 350) {
      this.status = this.followCursor ? 'Waiting for a gentle cursor' : 'Natural behavior'; return null;
    }
    this.status = distance(mouse, fly.pos) <= 150 ? 'Waiting by cursor' : 'Following cursor';
    return { target: mouse, stopRadius: 150, feeding: false };
  }
}
