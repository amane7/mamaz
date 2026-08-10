import { describe, expect, it } from 'vitest';
import { generateBookingSlot, projectAvailabilityForAdmin } from './scheduling';
import type { Appointment, BookingPlan, MidwifeAvailability, MidwifeProfile } from './types';

const plan: BookingPlan = {
  id: 'plan-online',
  facilityId: 'facility-1',
  type: 'オンライン相談',
  name: 'オンライン相談',
  durationMin: 60,
  description: 'test'
};

const midwife = (patch: Partial<MidwifeProfile> = {}): MidwifeProfile => ({
  id: 'mw-1',
  name: 'テスト助産師',
  facilityId: 'facility-1',
  qualifications: ['助産師'],
  specialties: [],
  skills: [],
  supportedServices: ['オンライン相談', '母乳外来'],
  workHours: '9:00-17:00',
  area: '世田谷区',
  status: 'online',
  bufferMin: 30,
  dailyLimit: 6,
  consecutiveLimit: 3,
  ...patch
});

const availability = (
  kind: 'OK' | 'NG',
  start: string,
  end: string,
  patch: Partial<MidwifeAvailability> = {}
): MidwifeAvailability => ({
  id: `${kind}-${start}`,
  midwifeId: 'mw-1',
  kind,
  start,
  end,
  reasonVisibility: 'private',
  recurrence: 'none',
  source: 'midwife',
  createdBy: 'テスト助産師',
  createdAt: '2026-08-01T00:00:00.000Z',
  updatedAt: '2026-08-01T00:00:00.000Z',
  ...patch
});

const appointment = (patch: Partial<Appointment> = {}): Appointment => ({
  id: 'appointment-1',
  patientId: 'patient-2',
  facilityId: 'facility-1',
  planId: plan.id,
  start: '2026-08-12T13:00:00.000Z',
  durationMin: 60,
  type: 'オンライン相談',
  status: '確定',
  workflowStatus: 'CONFIRMED',
  assignedMidwifeId: 'mw-1',
  ...patch
});

const generate = (args: {
  start?: string;
  plan?: BookingPlan;
  midwives?: MidwifeProfile[];
  availability?: MidwifeAvailability[];
  appointments?: Appointment[];
  excludeAppointmentId?: string;
} = {}) => generateBookingSlot({
  start: args.start || '2026-08-12T10:00:00.000Z',
  plan: args.plan || plan,
  patientId: 'patient-1',
  midwives: args.midwives || [midwife()],
  availability: args.availability || [],
  appointments: args.appointments || [],
  excludeAppointmentId: args.excludeAppointmentId
});

describe('generateBookingSlot', () => {
  it('予約時間と前後バッファ全体を含む明示的なOK時間を必須にする', () => {
    const missing = generate();
    expect(missing.available).toBe(false);
    expect(missing.candidates[0].exclusionCodes).toContain('NO_EXPLICIT_OK');

    const covered = generate({
      availability: [availability('OK', '2026-08-12T09:30:00.000Z', '2026-08-12T11:30:00.000Z')]
    });
    expect(covered.available).toBe(true);
  });

  it('OK時間内でもNGと1分以上重なる候補を除外する', () => {
    const generated = generate({
      availability: [
        availability('OK', '2026-08-12T09:00:00.000Z', '2026-08-12T12:00:00.000Z'),
        availability('NG', '2026-08-12T10:59:00.000Z', '2026-08-12T11:01:00.000Z', { reason: '非公開予定' })
      ]
    });
    expect(generated.available).toBe(false);
    expect(generated.candidates[0].exclusionCodes).toContain('NG_CONFLICT');
  });

  it('必要スキルをすべて持たない助産師を除外する', () => {
    const breastPlan: BookingPlan = { ...plan, id: 'breast', type: '母乳外来', requiresQualification: 'IBCLC' };
    const generated = generate({
      plan: breastPlan,
      availability: [availability('OK', '2026-08-12T09:00:00.000Z', '2026-08-12T12:00:00.000Z')]
    });
    expect(generated.available).toBe(false);
    expect(generated.candidates[0].exclusionCodes).toContain('SKILL_MISMATCH');
  });

  it('毎週の基本パターンを同じ曜日へ展開する', () => {
    const generated = generate({
      start: '2026-08-19T10:00:00.000Z',
      availability: [availability('OK', '2026-08-12T09:30:00.000Z', '2026-08-12T11:30:00.000Z', { recurrence: 'weekly' })]
    });
    expect(generated.available).toBe(true);
  });

  it('日次上限と有効な予約競合を判定し、期限切れ仮押さえは無視する', () => {
    const ok = availability('OK', '2026-08-12T09:00:00.000Z', '2026-08-12T12:00:00.000Z');
    const limited = generate({
      midwives: [midwife({ dailyLimit: 1 })],
      availability: [ok],
      appointments: [appointment({ start: '2026-08-12T08:00:00.000Z' })]
    });
    expect(limited.candidates[0].exclusionCodes).toContain('DAILY_LIMIT');

    const expiredHold = generate({
      availability: [ok],
      appointments: [appointment({
        start: '2026-08-12T10:00:00.000Z',
        status: '仮押さえ',
        workflowStatus: 'SLOT_HELD',
        holdExpiresAt: '2020-01-01T00:00:00.000Z'
      })]
    });
    expect(expiredHold.available).toBe(true);
  });

  it('日時変更時に対象予約自身を競合判定から除外できる', () => {
    const generated = generate({
      availability: [availability('OK', '2026-08-12T09:00:00.000Z', '2026-08-12T12:00:00.000Z')],
      appointments: [appointment({ id: 'self', start: '2026-08-12T10:00:00.000Z' })],
      excludeAppointmentId: 'self'
    });
    expect(generated.available).toBe(true);
  });
});

describe('projectAvailabilityForAdmin', () => {
  it('管理者向け投影からNG理由を除去する', () => {
    const projected = projectAvailabilityForAdmin([
      availability('NG', '2026-08-12T10:00:00.000Z', '2026-08-12T11:00:00.000Z', { reason: '私用' })
    ]);
    expect(projected[0]).not.toHaveProperty('reason');
    expect(projected[0].kind).toBe('NG');
  });
});
