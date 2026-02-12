
import React, { useState } from 'react';
import { LIBRARY_TRACKS } from '../constants';

const LibraryScreen: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'songs' | 'playlists'>('songs');

  return (
    <div className="pb-32 px-6 pt-12 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <header className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight">Library</h1>
          <p className="text-slate-500 dark:text-slate-400 text-sm">Your favorite sounds</p>
        </div>
        <div className="w-12 h-12 rounded-full bg-primary/20 flex items-center justify-center overflow-hidden border-2 border-white dark:border-slate-700">
          <img 
            alt="User Profile" 
            className="w-full h-full object-cover" 
            src="https://picsum.photos/seed/user-lib/100/100"
          />
        </div>
      </header>

      {/* Tabs */}
      <div className="mb-8">
        <div className="bg-slate-200/50 dark:bg-slate-800/50 p-1.5 rounded-full flex gap-1 bubbly-shadow">
          <button 
            onClick={() => setActiveTab('songs')}
            className={`flex-1 py-3 px-4 rounded-full font-bold text-sm transition-all ${
              activeTab === 'songs' 
                ? 'bg-white dark:bg-slate-700 shadow-sm text-secondary dark:text-white' 
                : 'text-slate-500 dark:text-slate-400'
            }`}
          >
            All Songs
          </button>
          <button 
            onClick={() => setActiveTab('playlists')}
            className={`flex-1 py-3 px-4 rounded-full font-bold text-sm transition-all ${
              activeTab === 'playlists' 
                ? 'bg-white dark:bg-slate-700 shadow-sm text-secondary dark:text-white' 
                : 'text-slate-500 dark:text-slate-400'
            }`}
          >
            Playlists
          </button>
        </div>
      </div>

      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-bold">Featured Tracks</h2>
        <button className="flex items-center gap-1 text-primary font-bold text-sm">
          View all <span className="material-icons-round text-sm">chevron_right</span>
        </button>
      </div>

      {/* Track List */}
      <div className="space-y-4 mb-10">
        {LIBRARY_TRACKS.map((track) => (
          <div key={track.id} className="bg-white dark:bg-card-dark p-3 rounded-3xl flex items-center gap-4 bubbly-shadow active:scale-[0.98] transition-transform cursor-pointer">
            <div className="relative w-16 h-16 rounded-2xl overflow-hidden shadow-md flex-shrink-0">
              <img alt="Album Art" className="w-full h-full object-cover" src={track.imageUrl} />
              <div className="absolute inset-0 bg-black/10 flex items-center justify-center">
                <span className="material-icons-round text-white">play_arrow</span>
              </div>
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="font-bold text-secondary dark:text-white leading-tight truncate">{track.title}</h3>
              <p className="text-slate-500 dark:text-slate-400 text-xs mt-0.5 truncate">{track.artist} • {track.duration}</p>
            </div>
            <button className={`w-10 h-10 rounded-full flex items-center justify-center ${track.id === 'l2' ? 'text-primary' : 'text-slate-300 dark:text-slate-600'}`}>
              <span className="material-icons-round">{track.id === 'l2' ? 'favorite' : 'more_vert'}</span>
            </button>
          </div>
        ))}
      </div>

      {/* Horizontal Scroll */}
      <div className="pt-6">
        <h2 className="text-lg font-bold mb-4">Jump Back In</h2>
        <div className="flex gap-4 overflow-x-auto pb-4 -mx-6 px-6 no-scrollbar snap-x">
          <div className="min-w-[160px] snap-center cursor-pointer">
            <div className="w-full aspect-square rounded-3xl bg-primary/10 p-2 overflow-hidden mb-2">
              <img 
                alt="Playlist" 
                className="w-full h-full object-cover rounded-2xl shadow-sm" 
                src="https://picsum.photos/seed/brew/300/300" 
              />
            </div>
            <p className="font-bold text-sm px-1">Morning Brew</p>
          </div>
          <div className="min-w-[160px] snap-center cursor-pointer">
            <div className="w-full aspect-square rounded-3xl bg-blue-100 dark:bg-blue-900/20 p-2 overflow-hidden mb-2">
              <img 
                alt="Playlist" 
                className="w-full h-full object-cover rounded-2xl shadow-sm" 
                src="https://picsum.photos/seed/work/300/300" 
              />
            </div>
            <p className="font-bold text-sm px-1">Deep Work</p>
          </div>
        </div>
      </div>

      {/* FAB */}
      <button className="fixed bottom-28 right-6 w-16 h-16 bg-primary text-white rounded-full shadow-lg shadow-primary/30 flex items-center justify-center hover:scale-105 active:scale-95 transition-all z-10">
        <span className="material-icons-round text-4xl">add</span>
      </button>
    </div>
  );
};

export default LibraryScreen;
