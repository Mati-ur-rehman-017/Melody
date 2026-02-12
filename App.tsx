
import React, { useState, useEffect } from 'react';
import { Screen } from './types';
import DiscoverScreen from './components/DiscoverScreen';
import LibraryScreen from './components/LibraryScreen';

const App: React.FC = () => {
  const [currentScreen, setCurrentScreen] = useState<Screen>('discover');
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDarkMode]);

  const toggleDarkMode = () => setIsDarkMode(prev => !prev);

  const renderScreen = () => {
    switch (currentScreen) {
      case 'discover':
        return <DiscoverScreen />;
      case 'library':
        return <LibraryScreen />;
      case 'podcasts':
        return (
          <div className="flex flex-col items-center justify-center h-[70vh] text-center px-6">
            <span className="material-icons-round text-6xl text-primary mb-4">podcasts</span>
            <h2 className="text-2xl font-bold">Podcasts</h2>
            <p className="text-slate-500 mt-2">Discover your favorite stories and deep conversations.</p>
          </div>
        );
      case 'profile':
        return (
          <div className="flex flex-col items-center justify-center h-[70vh] text-center px-6">
            <span className="material-icons-round text-6xl text-secondary dark:text-white mb-4">person</span>
            <h2 className="text-2xl font-bold">User Profile</h2>
            <p className="text-slate-500 mt-2">Manage your account and preferences.</p>
          </div>
        );
      default:
        return <DiscoverScreen />;
    }
  };

  return (
    <div className="min-h-screen relative max-w-md mx-auto overflow-x-hidden">
      {/* Dynamic Screen */}
      <main className="min-h-screen">
        {renderScreen()}
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-8 left-1/2 -translate-x-1/2 w-[90%] max-w-[400px] bg-secondary dark:bg-black rounded-full py-3 px-6 flex items-center justify-between bubbly-shadow z-50">
        <button 
          onClick={() => setCurrentScreen('discover')}
          className={`flex flex-col items-center transition-all ${currentScreen === 'discover' ? 'text-primary scale-110' : 'text-white opacity-40'}`}
        >
          <span className="material-icons-round">explore</span>
          {currentScreen === 'discover' && <span className="text-[10px] font-bold">Explore</span>}
        </button>
        <button 
          onClick={() => setCurrentScreen('library')}
          className={`flex flex-col items-center transition-all ${currentScreen === 'library' ? 'text-primary scale-110' : 'text-white opacity-40'}`}
        >
          <span className="material-icons-round">library_music</span>
          {currentScreen === 'library' && <span className="text-[10px] font-bold">Library</span>}
        </button>
        <button 
          onClick={() => setCurrentScreen('podcasts')}
          className={`flex flex-col items-center transition-all ${currentScreen === 'podcasts' ? 'text-primary scale-110' : 'text-white opacity-40'}`}
        >
          <span className="material-icons-round">podcasts</span>
          {currentScreen === 'podcasts' && <span className="text-[10px] font-bold">Podcasts</span>}
        </button>
        <button 
          onClick={() => setCurrentScreen('profile')}
          className={`flex flex-col items-center transition-all ${currentScreen === 'profile' ? 'text-primary scale-110' : 'text-white opacity-40'}`}
        >
          <span className="material-icons-round">person</span>
          {currentScreen === 'profile' && <span className="text-[10px] font-bold">Profile</span>}
        </button>
      </nav>

      {/* Theme Toggle Button */}
      <div className="fixed top-4 right-4 z-[60]">
        <button 
          onClick={toggleDarkMode}
          className="w-10 h-10 rounded-full bg-secondary text-white flex items-center justify-center shadow-lg active:scale-90 transition-transform"
        >
          <span className="material-icons-round text-sm">{isDarkMode ? 'light_mode' : 'dark_mode'}</span>
        </button>
      </div>

      {/* App Bar Decoration */}
      <div className="fixed bottom-2 left-1/2 -translate-x-1/2 w-32 h-1 bg-slate-400/20 dark:bg-slate-700/50 rounded-full z-[40]"></div>
    </div>
  );
};

export default App;
