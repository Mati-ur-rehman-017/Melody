
import React from 'react';
import { CATEGORIES, RECOMMENDED_TRACKS } from '../constants';

const DiscoverScreen: React.FC = () => {
  return (
    <div className="pb-32 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Header */}
      <header className="px-6 flex items-center justify-between mb-8 mt-4">
        <div className="flex items-center gap-3">
          <div className="relative">
            <img 
              alt="User profile" 
              className="w-12 h-12 rounded-full border-2 border-white dark:border-gray-800 object-cover" 
              src="https://picsum.photos/seed/user/100/100"
            />
            <div className="absolute -top-1 -right-1 w-4 h-4 bg-primary rounded-full border-2 border-background-light dark:border-background-dark"></div>
          </div>
          <div>
            <p className="text-xs opacity-60 font-medium">Welcome Back,</p>
            <h1 className="text-lg font-bold">John Doe</h1>
          </div>
        </div>
        <button className="w-12 h-12 rounded-full bg-white dark:bg-card-dark flex items-center justify-center bubbly-shadow">
          <span className="material-icons-round text-secondary dark:text-gray-200">notifications</span>
        </button>
      </header>

      {/* Search */}
      <section className="px-6 mb-8">
        <div className="relative group">
          <span className="material-icons-round absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-primary transition-colors">search</span>
          <input 
            className="w-full bg-white dark:bg-card-dark border-none rounded-full py-4 pl-12 pr-6 bubbly-shadow focus:ring-2 focus:ring-primary/20 text-sm font-medium transition-all" 
            placeholder="Search for songs, artists..." 
            type="text"
          />
          <button className="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center">
            <span className="material-icons-round text-sm">tune</span>
          </button>
        </div>
      </section>

      {/* Categories */}
      <section className="mb-8">
        <div className="px-6 flex justify-between items-end mb-4">
          <h2 className="text-xl font-bold">Categories</h2>
          <button className="text-primary text-sm font-semibold">See all</button>
        </div>
        <div className="flex gap-4 overflow-x-auto px-6 pb-2 no-scrollbar">
          {CATEGORIES.map((cat) => (
            <div key={cat.id} className="flex flex-col items-center gap-2 flex-shrink-0">
              <div className="w-16 h-16 rounded-full bg-white dark:bg-card-dark flex items-center justify-center bubbly-shadow active:scale-95 transition-transform cursor-pointer">
                <span className={`material-icons-round ${cat.color} text-3xl`}>{cat.icon}</span>
              </div>
              <span className="text-xs font-semibold">{cat.name}</span>
            </div>
          ))}
        </div>
      </section>

      {/* Recommended */}
      <section className="px-6">
        <div className="flex justify-between items-end mb-4">
          <h2 className="text-xl font-bold">Recommended</h2>
          <span className="material-icons-round text-gray-400 cursor-pointer">more_horiz</span>
        </div>
        <div className="grid grid-cols-2 gap-4">
          {RECOMMENDED_TRACKS.map((track) => (
            <div 
              key={track.id} 
              className={`${track.colorBg} dark:bg-gray-800/50 rounded-3xl p-4 flex flex-col items-center text-center active:scale-[0.98] transition-all cursor-pointer bubbly-shadow`}
            >
              <div className="relative w-full aspect-square mb-4 group">
                <div className="absolute inset-0 bg-secondary rounded-full overflow-hidden flex items-center justify-center">
                  <img 
                    alt="Track Art" 
                    className="w-full h-full object-cover opacity-80 group-hover:scale-110 transition-transform duration-700" 
                    src={track.imageUrl}
                  />
                  <div className={`absolute w-12 h-12 ${track.colorBg} dark:bg-gray-800 rounded-full border-4 ${track.accentColor} flex items-center justify-center`}>
                    <div className="w-2 h-2 bg-secondary dark:bg-white rounded-full"></div>
                  </div>
                </div>
              </div>
              <p className="text-[10px] text-primary font-bold uppercase tracking-wider mb-1">{track.category}</p>
              <h3 className="text-sm font-bold leading-tight mb-2 h-10 flex items-center justify-center">{track.title}</h3>
              <p className="text-[10px] opacity-60">{track.artist}</p>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};

export default DiscoverScreen;
