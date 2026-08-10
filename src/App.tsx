import { useState } from 'react';
import { useStore } from './store';
import type { AppMode } from './types';
import { Landing } from './screens/Landing';
import { MidwifeApp } from './screens/MidwifeApp';
import { MamaApp } from './screens/MamaApp';
import { AdminApp } from './screens/AdminApp';

export default function App() {
  const [mode, setMode] = useState<AppMode>(() => {
    const requested = new URLSearchParams(window.location.search).get('mode');
    return requested === 'mama' || requested === 'midwife' || requested === 'admin' ? requested : 'landing';
  });
  const store = useStore();

  if (mode === 'landing') {
    return (
      <Landing
        onEnter={setMode}
        config={store.state.config}
        onUpdateConfig={store.updateConfig}
      />
    );
  }
  if (mode === 'midwife') {
    return <MidwifeApp store={store} onExit={() => setMode('landing')} />;
  }
  if (mode === 'admin') {
    return <AdminApp store={store} onExit={() => setMode('landing')} />;
  }
  return <MamaApp store={store} onExit={() => setMode('landing')} />;
}
