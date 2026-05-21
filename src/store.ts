import { useEffect, useState, useCallback } from 'react';
import type { AppState, LogEntry, MamaCheck, ChatMessage } from './types';

const KEY = 'mamaz_state_v1';

function seedState(): AppState {
  const now = Date.now();
  const birthday = new Date(now - 1000 * 60 * 60 * 24 * 42).toISOString(); // 生後42日
  const baseLogs: LogEntry[] = [];
  // 過去24時間のサンプル授乳ログ
  for (let i = 0; i < 6; i++) {
    baseLogs.push({
      id: `f${i}`,
      type: 'feeding',
      at: now - (i * 3 + 1) * 60 * 60 * 1000,
      side: i % 2 === 0 ? 'left' : 'right',
      durationMin: 15 + Math.floor(Math.random() * 10),
      amountMl: 80 + Math.floor(Math.random() * 40),
    });
  }
  // 睡眠
  for (let i = 0; i < 4; i++) {
    const end = now - i * 5 * 60 * 60 * 1000;
    baseLogs.push({
      id: `s${i}`,
      type: 'sleep',
      at: end,
      sleepStart: end - (60 + Math.random() * 120) * 60 * 1000,
      sleepEnd: end,
    });
  }
  // おむつ
  for (let i = 0; i < 5; i++) {
    baseLogs.push({
      id: `d${i}`,
      type: 'diaper',
      at: now - (i * 4 + 2) * 60 * 60 * 1000,
      diaper: i % 3 === 0 ? 'poop' : 'pee',
    });
  }

  return {
    baby: {
      name: 'はる',
      birthday,
      gender: 'unknown',
      avatar: '👶',
    },
    mama: {
      name: 'あなた',
      deliveryDate: birthday,
      deliveryType: '自然分娩',
      partnerName: 'パートナー',
      avatar: '🌸',
    },
    logs: baseLogs,
    mamaChecks: [
      {
        id: 'mc1',
        at: now - 1000 * 60 * 60 * 24,
        sleepHours: 4.5,
        moodScore: 6,
        bodyPainScore: 4,
        stressScore: 5,
        hasHelp: true,
        notes: '少し疲れた日。',
      },
    ],
    chat: [
      {
        id: 'c1',
        role: 'mami',
        text: 'はじめまして、AIケアパートナーの mami です🌸 産後のからだと心、赤ちゃんのこと、なんでも気軽に話しかけてくださいね。',
        at: Date.now(),
      },
    ],
    onboarded: false,
  };
}

function loadState(): AppState {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return seedState();
    const parsed = JSON.parse(raw) as AppState;
    // 後方互換チェック
    if (!parsed.chat) parsed.chat = seedState().chat;
    return parsed;
  } catch {
    return seedState();
  }
}

function saveState(state: AppState) {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    // ignore
  }
}

export function useAppState() {
  const [state, setState] = useState<AppState>(() => loadState());

  useEffect(() => {
    saveState(state);
  }, [state]);

  const addLog = useCallback((log: Omit<LogEntry, 'id'>) => {
    setState((s) => ({
      ...s,
      logs: [{ ...log, id: crypto.randomUUID() }, ...s.logs],
    }));
  }, []);

  const removeLog = useCallback((id: string) => {
    setState((s) => ({ ...s, logs: s.logs.filter((l) => l.id !== id) }));
  }, []);

  const addMamaCheck = useCallback((mc: Omit<MamaCheck, 'id'>) => {
    setState((s) => ({
      ...s,
      mamaChecks: [{ ...mc, id: crypto.randomUUID() }, ...s.mamaChecks],
    }));
  }, []);

  const addChat = useCallback((msg: Omit<ChatMessage, 'id'>) => {
    setState((s) => ({
      ...s,
      chat: [...s.chat, { ...msg, id: crypto.randomUUID() }],
    }));
  }, []);

  const completeOnboarding = useCallback(
    (baby: Partial<AppState['baby']>, mama: Partial<AppState['mama']>) => {
      setState((s) => ({
        ...s,
        baby: { ...s.baby, ...baby },
        mama: { ...s.mama, ...mama },
        onboarded: true,
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
    addLog,
    removeLog,
    addMamaCheck,
    addChat,
    completeOnboarding,
    reset,
  };
}
