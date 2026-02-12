
import { Category, Track } from './types';

export const CATEGORIES: Category[] = [
  { id: '1', name: 'Touching', icon: 'pan_tool', color: 'text-primary' },
  { id: '2', name: 'Listening', icon: 'hearing', color: 'text-accent' },
  { id: '3', name: 'Speaking', icon: 'campaign', color: 'text-blue-400' },
  { id: '4', name: 'Visual', icon: 'visibility', color: 'text-green-500' },
  { id: '5', name: 'Focus', icon: 'psychology', color: 'text-purple-500' },
];

export const RECOMMENDED_TRACKS: Track[] = [
  {
    id: 'r1',
    title: 'Connecting Beyond Words',
    artist: '30 min • English',
    duration: '30:00',
    category: 'TOUCHING',
    imageUrl: 'https://picsum.photos/seed/music1/400/400',
    colorBg: 'bg-[#F2E8D5]',
    accentColor: 'border-secondary',
  },
  {
    id: 'r2',
    title: 'Unlocking Empathy',
    artist: '25 min • English',
    duration: '25:00',
    category: 'LISTENING',
    imageUrl: 'https://picsum.photos/seed/music2/400/400',
    colorBg: 'bg-[#E5EDF0]',
    accentColor: 'border-primary',
  },
  {
    id: 'r3',
    title: 'Vocal Mastery',
    artist: '45 min • English',
    duration: '45:00',
    category: 'SPEAKING',
    imageUrl: 'https://picsum.photos/seed/music3/400/400',
    colorBg: 'bg-[#FDE4E4]',
    accentColor: 'border-accent',
  },
  {
    id: 'r4',
    title: 'Morning Rituals',
    artist: '12 min • English',
    duration: '12:00',
    category: 'MINDSET',
    imageUrl: 'https://picsum.photos/seed/music4/400/400',
    colorBg: 'bg-[#E9F4F0]',
    accentColor: 'border-secondary',
  },
];

export const LIBRARY_TRACKS: Track[] = [
  {
    id: 'l1',
    title: 'Beyond the Horizon',
    artist: 'Lofi Dreaming',
    duration: '3:45',
    category: 'Lofi',
    imageUrl: 'https://picsum.photos/seed/lofi/100/100',
    colorBg: 'bg-white',
    accentColor: 'text-primary',
  },
  {
    id: 'l2',
    title: 'Neon Soul',
    artist: 'The Electric Funk',
    duration: '4:12',
    category: 'Funk',
    imageUrl: 'https://picsum.photos/seed/neon/100/100',
    colorBg: 'bg-white',
    accentColor: 'text-primary',
  },
  {
    id: 'l3',
    title: 'Forest Rain',
    artist: 'Ambient Nature',
    duration: '10:00',
    category: 'Ambient',
    imageUrl: 'https://picsum.photos/seed/forest/100/100',
    colorBg: 'bg-white',
    accentColor: 'text-primary',
  },
  {
    id: 'l4',
    title: 'Midnight Pulse',
    artist: 'Synthwave Collective',
    duration: '5:24',
    category: 'Synthwave',
    imageUrl: 'https://picsum.photos/seed/pulse/100/100',
    colorBg: 'bg-white',
    accentColor: 'text-primary',
  },
];
