import type { Consumer } from './consumer.port.js';

/**
 * In-process registry of all `Consumer` objects. The dispatcher iterates
 * `all()` every tick. Replaces the old `EventBus.subscribe` indirection —
 * with per-consumer offsets, fan-out IS the registry, no bus needed.
 *
 * Late-joining consumers: a Consumer registered after some events have
 * been written gets `committedSeq = 0` from the dispatcher (start from
 * earliest). To start a new consumer at "latest" instead, seed its row
 * manually in a migration. Most new consumers want earliest — process the
 * backlog, learn from history.
 */
export class ConsumerRegistry {
  private readonly byName = new Map<string, Consumer>();

  register(consumer: Consumer): void {
    if (this.byName.has(consumer.name)) {
      throw new Error(
        `Consumer with name "${consumer.name}" is already registered. Consumer names must be globally unique.`,
      );
    }
    this.byName.set(consumer.name, consumer);
  }

  all(): readonly Consumer[] {
    return Array.from(this.byName.values());
  }

  forTopic(topic: string): readonly Consumer[] {
    return Array.from(this.byName.values()).filter((c) => c.topic === topic);
  }

  has(name: string): boolean {
    return this.byName.has(name);
  }

  get(name: string): Consumer | undefined {
    return this.byName.get(name);
  }
}
