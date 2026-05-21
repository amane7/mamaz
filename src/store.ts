import { useCallback, useEffect, useState } from 'react';
import type {
  Patient,
  Appointment,
  IntakeForm,
  ChartEntry,
  PhotoEntry,
  ChatMessage,
} from './types';
import {
  seedAppointments,
  seedCharts,
  seedChats,
  seedIntakes,
  seedPatients,
  seedPhotos,
} from './seed';

const KEY = 'manary_state_v2';

interface State {
  patients: Patient[];
  appointments: Appointment[];
  intakes: IntakeForm[];
  charts: ChartEntry[];
  photos: PhotoEntry[];
  chats: ChatMessage[];
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
    dark: false,
  };
}

function load(): State {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return seedState();
    const p = JSON.parse(raw) as State;
    return { ...seedState(), ...p };
  } catch {
    return seedState();
  }
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
    reset,
  };
}
