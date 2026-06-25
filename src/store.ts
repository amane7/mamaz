import { useCallback, useEffect, useState } from 'react';
import type {
  Patient,
  Appointment,
  IntakeForm,
  ChartEntry,
  PhotoEntry,
  ChatMessage,
  ShiftSlot,
  LineNotification,
  AppConfig,
} from './types';
import {
  seedAppointments,
  seedCharts,
  seedChats,
  seedIntakes,
  seedPatients,
  seedPhotos,
  seedShifts,
  seedLineNotifications,
  seedConfig,
} from './seed';

const KEY = 'manary_state_v3';

interface State {
  patients: Patient[];
  appointments: Appointment[];
  intakes: IntakeForm[];
  charts: ChartEntry[];
  photos: PhotoEntry[];
  chats: ChatMessage[];
  shifts: ShiftSlot[];
  lineNotifications: LineNotification[];
  config: AppConfig;
  dark: boolean;
}

function seedState(): State {
  return {
    patients: seedPatients,
    appointments: seedAppointments,
    intakes: seedIntakes,
    charts: seedCharts,
    photos: seedPhotos,
    chats: seedChats,
    shifts: seedShifts,
    lineNotifications: seedLineNotifications,
    config: seedConfig,
    dark: true, // クール・未来的にあわせてダーク既定
  };
}

function load(): State {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return seedState();
    const p = JSON.parse(raw) as Partial<State>;
    return { ...seedState(), ...p };
  } catch {
    return seedState();
  }
}

// ───── 予約衝突判定 ─────
// 同じ時間帯（durationMin 範囲）に他の予約があれば true
export function hasOverlap(
  appointments: Appointment[],
  startISO: string,
  durationMin: number,
  excludeId?: string,
): boolean {
  const startA = new Date(startISO).getTime();
  const endA = startA + durationMin * 60_000;
  return appointments.some((a) => {
    if (a.id === excludeId) return false;
    if (a.status === 'キャンセル') return false;
    const startB = new Date(a.start).getTime();
    const endB = startB + a.durationMin * 60_000;
    // 重なる条件: A.start < B.end かつ B.start < A.end
    return startA < endB && startB < endA;
  });
}

export function useStore() {
  const [state, setState] = useState<State>(() => load());

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(state));
    } catch {}
    document.documentElement.classList.toggle('dark', state.dark);
  }, [state]);

  const setDark = useCallback(
    (v: boolean) => setState((s) => ({ ...s, dark: v })),
    [],
  );

  const addChart = useCallback((c: Omit<ChartEntry, 'id'>) => {
    setState((s) => ({
      ...s,
      charts: [{ ...c, id: crypto.randomUUID() }, ...s.charts],
    }));
  }, []);

  const updateAppointmentStatus = useCallback(
    (id: string, status: Appointment['status']) => {
      setState((s) => ({
        ...s,
        appointments: s.appointments.map((a) =>
          a.id === id ? { ...a, status } : a,
        ),
      }));
    },
    [],
  );

  const addChat = useCallback((m: Omit<ChatMessage, 'id'>) => {
    setState((s) => ({
      ...s,
      chats: [...s.chats, { ...m, id: crypto.randomUUID() }],
    }));
  }, []);

  const addIntake = useCallback((i: Omit<IntakeForm, 'id'>) => {
    setState((s) => ({
      ...s,
      intakes: [{ ...i, id: crypto.randomUUID() }, ...s.intakes],
    }));
  }, []);

  const addPhoto = useCallback((p: Omit<PhotoEntry, 'id'>) => {
    setState((s) => ({
      ...s,
      photos: [{ ...p, id: crypto.randomUUID() }, ...s.photos],
    }));
  }, []);

  // ───── 予約・問診セット作成（ダブルブッキング防止） ─────
  const bookAppointmentWithIntake = useCallback(
    (
      appt: Omit<Appointment, 'id' | 'status' | 'intakeId'>,
      intake: Omit<IntakeForm, 'id' | 'appointmentId'>,
    ): { ok: true; appointmentId: string } | { ok: false; reason: string } => {
      let result: ReturnType<typeof bookAppointmentWithIntake> = {
        ok: false,
        reason: '不明なエラー',
      };
      setState((s) => {
        if (hasOverlap(s.appointments, appt.start, appt.durationMin)) {
          result = { ok: false, reason: 'この時間帯はすでに予約があります。' };
          return s;
        }
        const aid = crypto.randomUUID();
        const iid = crypto.randomUUID();
        const newAppt: Appointment = {
          ...appt,
          id: aid,
          status: '予約済',
          intakeId: iid,
        };
        const newIntake: IntakeForm = {
          ...intake,
          id: iid,
          appointmentId: aid,
          submittedAt: new Date().toISOString(),
        };
        const notification: LineNotification = {
          id: crypto.randomUUID(),
          at: new Date().toISOString(),
          channel: 'official-line',
          to: '公式LINE',
          message: `🌸 予約入ってよかちゃん！\n${intake.motherName}様 (赤ちゃん: ${intake.babyName})\n${formatJpDateTime(appt.start)} / ${appt.type} (${appt.durationMin}分)`,
          triggeredBy: '予約作成 (アプリ)',
        };
        result = { ok: true, appointmentId: aid };
        return {
          ...s,
          appointments: [...s.appointments, newAppt],
          intakes: [newIntake, ...s.intakes],
          lineNotifications: [notification, ...s.lineNotifications],
        };
      });
      return result;
    },
    [],
  );

  // ───── シフトトグル ─────
  const toggleShift = useCallback((id: string) => {
    setState((s) => ({
      ...s,
      shifts: s.shifts.map((sl) =>
        sl.id === id ? { ...sl, closed: !sl.closed } : sl,
      ),
    }));
  }, []);

  // ───── 設定変更 ─────
  const updateConfig = useCallback((patch: Partial<AppConfig>) => {
    setState((s) => ({ ...s, config: { ...s.config, ...patch } }));
  }, []);

  const addLineNotification = useCallback(
    (n: Omit<LineNotification, 'id'>) => {
      setState((s) => ({
        ...s,
        lineNotifications: [
          { ...n, id: crypto.randomUUID() },
          ...s.lineNotifications,
        ],
      }));
    },
    [],
  );

  const reset = useCallback(() => {
    localStorage.removeItem(KEY);
    setState(seedState());
  }, []);

  return {
    state,
    setDark,
    addChart,
    updateAppointmentStatus,
    addChat,
    addIntake,
    addPhoto,
    bookAppointmentWithIntake,
    toggleShift,
    updateConfig,
    addLineNotification,
    reset,
  };
}

function formatJpDateTime(iso: string) {
  const d = new Date(iso);
  const m = d.getMonth() + 1;
  const dd = d.getDate();
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${m}/${dd} ${hh}:${mm}`;
}
