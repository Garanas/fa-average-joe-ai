import { Injectable, PLATFORM_ID, effect, inject, signal } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';

import { DEFAULT_FACTION, FACTIONS, FactionId, isFactionId } from './faction-theme';

const STORAGE_KEY = 'fa-joe-ai-faction-theme';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));

  readonly current = signal<FactionId>(this.readInitial());

  constructor() {
    if (!this.isBrowser) {
      return;
    }
    effect(() => {
      const active = this.current();
      const classList = document.documentElement.classList;
      for (const faction of FACTIONS) {
        classList.toggle(`theme-${faction.id}`, faction.id === active);
      }
      try {
        localStorage.setItem(STORAGE_KEY, active);
      } catch {
        // Ignore storage failures (private mode, quota, etc.).
      }
    });
  }

  setTheme(id: FactionId): void {
    this.current.set(id);
  }

  private readInitial(): FactionId {
    if (!this.isBrowser) {
      return DEFAULT_FACTION;
    }
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return isFactionId(stored) ? stored : DEFAULT_FACTION;
    } catch {
      return DEFAULT_FACTION;
    }
  }
}
