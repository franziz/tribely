import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Venue } from './venue.js';

const valid = {
  address: '1 Raffles Place, Singapore',
  city: 'Singapore',
  latitude: 1.2841,
  longitude: 103.8511,
};

describe('Venue', () => {
  describe('create', () => {
    it('returns a Venue when input is valid', () => {
      const v = Venue.create(valid);
      expect(v.address).toBe(valid.address);
      expect(v.city).toBe(valid.city);
      expect(v.latitude).toBe(valid.latitude);
      expect(v.longitude).toBe(valid.longitude);
    });

    it('trims address whitespace', () => {
      const v = Venue.create({ ...valid, address: '  Marina Bay  ' });
      expect(v.address).toBe('Marina Bay');
    });

    it('trims city whitespace', () => {
      const v = Venue.create({ ...valid, city: '  Singapore  ' });
      expect(v.city).toBe('Singapore');
    });

    it('rejects an empty / whitespace-only address', () => {
      expect(() => Venue.create({ ...valid, address: '' })).toThrowError(AppError);
      expect(() => Venue.create({ ...valid, address: '   ' })).toThrowError(/address/);
    });

    it('rejects an empty / whitespace-only city', () => {
      expect(() => Venue.create({ ...valid, city: '' })).toThrowError(/city/);
      expect(() => Venue.create({ ...valid, city: '   ' })).toThrowError(/city/);
    });

    it('rejects an address longer than 300 chars', () => {
      expect(() => Venue.create({ ...valid, address: 'a'.repeat(301) })).toThrowError(/1-300/);
    });

    it('rejects a city longer than 120 chars', () => {
      expect(() => Venue.create({ ...valid, city: 'a'.repeat(121) })).toThrowError(/1-120/);
    });

    it.each([-90.0001, 90.0001, Number.NaN, Number.POSITIVE_INFINITY])(
      'rejects out-of-range latitude %s',
      (lat) => {
        expect(() => Venue.create({ ...valid, latitude: lat })).toThrowError(/latitude/);
      },
    );

    it.each([-180.0001, 180.0001, Number.NaN, Number.POSITIVE_INFINITY])(
      'rejects out-of-range longitude %s',
      (lng) => {
        expect(() => Venue.create({ ...valid, longitude: lng })).toThrowError(/longitude/);
      },
    );

    it('accepts the global boundary values', () => {
      expect(() =>
        Venue.create({ address: 'pole', city: 'Polar', latitude: -90, longitude: -180 }),
      ).not.toThrow();
      expect(() =>
        Venue.create({ address: 'pole', city: 'Polar', latitude: 90, longitude: 180 }),
      ).not.toThrow();
    });
  });

  describe('equals', () => {
    it('compares all four fields', () => {
      const a = Venue.create(valid);
      const b = Venue.create(valid);
      expect(a.equals(b)).toBe(true);
      expect(a.equals(Venue.create({ ...valid, latitude: 1.3 }))).toBe(false);
      expect(a.equals(Venue.create({ ...valid, city: 'Jakarta' }))).toBe(false);
    });
  });
});
