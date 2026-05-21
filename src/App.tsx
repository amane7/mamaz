import { useState } from 'react';
import { useAppState } from './store';
import type { ScreenId } from './types';
import { Onboarding } from './screens/Onboarding';
import { Home } from './screens/Home';
import { LogScreen } from './screens/LogScreen';
import { MamiChat } from './screens/MamiChat';
import { MamaCare } from './screens/MamaCare';
import { FutureLab } from './screens/FutureLab';
import { Community } from './screens/Community';
import { BottomNav } from './components/BottomNav';
import { TopBar } from './components/TopBar';

export default function App() {
  const store = useAppState();
  const [screen, setScreen] = useState<ScreenId>('home');

  if (!store.state.onboarded) {
    return <Onboarding onDone={store.completeOnboarding} />;
  }

  return (
    <div className="min-h-screen flex flex-col">
      <TopBar state={store.state} onReset={store.reset} />
      <main className="flex-1 max-w-2xl w-full mx-auto px-4 pt-4 safe-bottom">
        {screen === 'home' && (
          <Home state={store.state} go={setScreen} />
        )}
        {screen === 'log' && (
          <LogScreen
            state={store.state}
            addLog={store.addLog}
            removeLog={store.removeLog}
          />
        )}
        {screen === 'mami' && (
          <MamiChat state={store.state} addChat={store.addChat} />
        )}
        {screen === 'mama' && (
          <MamaCare state={store.state} addMamaCheck={store.addMamaCheck} />
        )}
        {screen === 'future' && <FutureLab state={store.state} />}
        {screen === 'community' && <Community state={store.state} />}
      </main>
      <BottomNav current={screen} onChange={setScreen} />
    </div>
  );
}
