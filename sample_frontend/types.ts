
export type Screen = 'discover' | 'library' | 'podcasts' | 'profile';

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
}

export interface Track {
  id: string;
  title: string;
  artist: string;
  duration: string;
  category: string;
  imageUrl: string;
  colorBg: string;
  accentColor: string;
}
