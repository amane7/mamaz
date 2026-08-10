import type {
  Appointment,
  BookingPlan,
  Facility,
  GeneratedBookingSlot,
  MidwifeAvailability,
  MidwifeProfile,
  SlotCandidate,
  SlotExclusionCode
} from './types';

const ACTIVE_WORKFLOWS = new Set(['SLOT_HELD', 'CONFIRMED', 'IN_SERVICE']);
const overlaps = (aStart: number, aEnd: number, bStart: number, bEnd: number) => aStart < bEnd && bStart < aEnd;
const minutes = (value: string) => +new Date(value) / 60000;
const sameDay = (value: string, date: string) => value.slice(0, 10) === date;
const isActiveBooking = (appointment: Appointment) => ACTIVE_WORKFLOWS.has(appointment.workflowStatus || '')
  && (appointment.workflowStatus !== 'SLOT_HELD' || !appointment.holdExpiresAt || +new Date(appointment.holdExpiresAt) > Date.now());

const availabilityBounds = (entry: MidwifeAvailability, targetStart: string) => {
  if (entry.recurrence !== 'weekly') return { start: minutes(entry.start), end: minutes(entry.end) };
  const sourceStart = new Date(entry.start);
  const sourceEnd = new Date(entry.end);
  const target = new Date(targetStart);
  if (targetStart.slice(0, 10) < entry.start.slice(0, 10) || sourceStart.getUTCDay() !== target.getUTCDay()) return undefined;
  const occurrenceStart = new Date(target);
  occurrenceStart.setUTCHours(sourceStart.getUTCHours(), sourceStart.getUTCMinutes(), 0, 0);
  const durationMin = Math.max(1, (+sourceEnd - +sourceStart) / 60000);
  return { start: +occurrenceStart / 60000, end: +occurrenceStart / 60000 + durationMin };
};

const requiredSkills = (plan: BookingPlan) => {
  const skills = ['助産師'];
  if (plan.requiresQualification) skills.push(plan.requiresQualification);
  if (plan.type === '母乳外来') skills.push('母乳ケア');
  if (plan.type === '訪問ケア') skills.push('訪問対応');
  if (plan.type === '宿泊ケア') skills.push('宿泊対応');
  return [...new Set(skills)];
};

const staffSkills = (midwife: MidwifeProfile) => new Set([
  ...midwife.qualifications,
  ...midwife.specialties,
  ...(midwife.skills || [])
]);

const dateBookings = (appointments: Appointment[], midwifeId: string, date: string, excludeAppointmentId?: string) => appointments
  .filter(a => a.id !== excludeAppointmentId && a.assignedMidwifeId === midwifeId && sameDay(a.start, date) && isActiveBooking(a))
  .sort((a, b) => a.start.localeCompare(b.start));

const estimateTravelMin = (
  appointment: Appointment | undefined,
  facility: Facility | undefined,
  plan: BookingPlan,
  midwife: MidwifeProfile
) => {
  if (!appointment || plan.type === 'オンライン相談') return 0;
  if (appointment.facilityId === facility?.id) return 0;
  if (plan.type === '訪問ケア' || appointment.type === '訪問ケア') return midwife.bufferMin || 30;
  return 20;
};

function evaluateMidwife(args: {
  start: string;
  plan: BookingPlan;
  patientId?: string;
  facility?: Facility;
  midwife: MidwifeProfile;
  availability: MidwifeAvailability[];
  appointments: Appointment[];
  excludeAppointmentId?: string;
}): SlotCandidate {
  const { start, plan, patientId, facility, midwife, availability, appointments, excludeAppointmentId } = args;
  const startMin = minutes(start);
  const end = new Date(+new Date(start) + plan.durationMin * 60000).toISOString();
  const endMin = minutes(end);
  const buffer = midwife.bufferMin || 0;
  const coveredStart = startMin - buffer;
  const coveredEnd = endMin + buffer;
  const exclusions: SlotExclusionCode[] = [];
  const reasons: string[] = [];
  const skills = staffSkills(midwife);
  const missing = requiredSkills(plan).filter(skill => !skills.has(skill));
  if (missing.length) {
    exclusions.push('SKILL_MISMATCH');
    reasons.push(`必要スキル不足: ${missing.join('・')}`);
  }
  if (midwife.supportedServices?.length && !midwife.supportedServices.includes(plan.type)) {
    exclusions.push('SKILL_MISMATCH');
    reasons.push('対応サービス外');
  }
  if (midwife.facilityId !== plan.facilityId && plan.type !== '訪問ケア' && plan.type !== 'オンライン相談') {
    exclusions.push('FACILITY_MISMATCH');
    reasons.push('所属施設条件外');
  }
  if (plan.type === '訪問ケア' && facility && !midwife.visitAreas?.includes(facility.area)) {
    exclusions.push('AREA_MISMATCH');
    reasons.push('訪問対応地域外');
  }

  const entries = availability.filter(x => x.midwifeId === midwife.id);
  const occurrenceEntries = entries
    .map(entry => ({ entry, bounds: availabilityBounds(entry, start) }))
    .filter((item): item is { entry: MidwifeAvailability; bounds: { start: number; end: number } } => Boolean(item.bounds));
  const ok = occurrenceEntries.some(({ entry, bounds }) => entry.kind === 'OK' && bounds.start <= coveredStart && bounds.end >= coveredEnd);
  if (!ok) {
    exclusions.push('NO_EXPLICIT_OK');
    reasons.push('予約時間と前後バッファを含むOK時間が未登録');
  }
  const ng = occurrenceEntries.some(({ entry, bounds }) => entry.kind === 'NG' && overlaps(coveredStart, coveredEnd, bounds.start, bounds.end));
  if (ng) {
    exclusions.push('NG_CONFLICT');
    reasons.push('対応不可時間と重複');
  }

  const booked = dateBookings(appointments, midwife.id, start.slice(0, 10), excludeAppointmentId);
  const conflict = booked.some(a => overlaps(coveredStart, coveredEnd, minutes(a.start) - buffer, minutes(a.start) + a.durationMin + buffer));
  if (conflict) {
    exclusions.push('BOOKING_CONFLICT');
    reasons.push('確定予約または仮押さえと重複');
  }
  if (booked.length >= (midwife.dailyLimit || Number.POSITIVE_INFINITY)) {
    exclusions.push('DAILY_LIMIT');
    reasons.push('1日対応上限に到達');
  }

  const priorBookings = booked.filter(a => minutes(a.start) + a.durationMin <= startMin);
  const before = priorBookings[priorBookings.length - 1];
  const after = booked.find(a => minutes(a.start) >= endMin);
  const travelBefore = estimateTravelMin(before, facility, plan, midwife);
  const travelAfter = estimateTravelMin(after, facility, plan, midwife);
  if (before && startMin - (minutes(before.start) + before.durationMin) < buffer) {
    exclusions.push('BUFFER_SHORTAGE');
    reasons.push('前予約とのバッファ不足');
  }
  if (after && minutes(after.start) - endMin < buffer) {
    exclusions.push('BUFFER_SHORTAGE');
    reasons.push('次予約とのバッファ不足');
  }
  if (before && startMin - (minutes(before.start) + before.durationMin) < travelBefore + buffer) {
    exclusions.push('TRAVEL_SHORTAGE');
    reasons.push('前予約からの移動時間不足');
  }
  if (after && minutes(after.start) - endMin < travelAfter + buffer) {
    exclusions.push('TRAVEL_SHORTAGE');
    reasons.push('次予約までの移動時間不足');
  }

  const contiguous = booked.filter(a => {
    const gapBefore = Math.abs(startMin - (minutes(a.start) + a.durationMin));
    const gapAfter = Math.abs(minutes(a.start) - endMin);
    return Math.min(gapBefore, gapAfter) <= buffer + 1;
  }).length;
  if (contiguous >= (midwife.consecutiveLimit || Number.POSITIVE_INFINITY)) {
    exclusions.push('CONSECUTIVE_LIMIT');
    reasons.push('連続対応上限に到達');
  }

  const loadBalance = Math.max(0, 50 - booked.length * 8);
  const travelEfficiency = Math.max(0, 30 - travelBefore - travelAfter);
  const continuity = patientId && appointments.some(a => a.patientId === patientId && a.assignedMidwifeId === midwife.id) ? 20 : 0;
  return {
    midwifeId: midwife.id,
    eligible: exclusions.length === 0,
    score: loadBalance + travelEfficiency + continuity,
    exclusionCodes: [...new Set(exclusions)],
    reasons: [...new Set(reasons)],
    scoreBreakdown: { loadBalance, travelEfficiency, continuity }
  };
}

export function generateBookingSlot(args: {
  start: string;
  plan: BookingPlan;
  patientId?: string;
  facility?: Facility;
  midwives: MidwifeProfile[];
  availability: MidwifeAvailability[];
  appointments: Appointment[];
  excludeAppointmentId?: string;
}): GeneratedBookingSlot {
  const end = new Date(+new Date(args.start) + args.plan.durationMin * 60000).toISOString();
  const candidates = args.midwives
    .map(midwife => evaluateMidwife({ ...args, midwife }))
    .sort((a, b) => Number(b.eligible) - Number(a.eligible) || b.score - a.score)
    .map((candidate, index) => ({ ...candidate, rank: candidate.eligible ? index + 1 : undefined }));
  const selected = candidates.find(x => x.eligible);
  return {
    start: args.start,
    end,
    available: Boolean(selected),
    candidates,
    selectedMidwifeId: selected?.midwifeId,
    publicReason: selected ? '必要な資格と対応可能時間を確認済み' : 'この時間は現在受付できません'
  };
}

export function projectAvailabilityForAdmin(entries: MidwifeAvailability[]) {
  return entries.map(({ reason: _reason, ...entry }) => entry);
}
