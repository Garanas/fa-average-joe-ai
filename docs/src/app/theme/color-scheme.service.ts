import { Injectable, PLATFORM_ID, effect, inject, signal } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';

export type ColorScheme = 'light' | 'dark' | 'auto';

const STORAGE_KEY = 'fa-joe-ai-color-scheme';
const ALL_SCHEMES: ColorScheme[] = ['light', 'dark', 'auto'];
const DEFAULT_SCHEME: ColorScheme = 'auto';

function isColorScheme(value: unknown): value is ColorScheme {
    return typeof value === 'string' && (ALL_SCHEMES as string[]).includes(value);
}

@Injectable({ providedIn: 'root' })
export class ColorSchemeService {
    private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));

    readonly current = signal<ColorScheme>(this.readInitial());

    constructor() {
        if (!this.isBrowser) {
            return;
        }
        effect(() => {
            const scheme = this.current();
            const root = document.documentElement;
            if (scheme === 'auto') {
                root.removeAttribute('data-color-scheme');
            } else {
                root.setAttribute('data-color-scheme', scheme);
            }
            try {
                localStorage.setItem(STORAGE_KEY, scheme);
            } catch {
                // Ignore storage failures (private mode, quota, etc.).
            }
        });
    }

    setScheme(scheme: ColorScheme): void {
        this.current.set(scheme);
    }

    cycle(): void {
        const idx = ALL_SCHEMES.indexOf(this.current());
        this.current.set(ALL_SCHEMES[(idx + 1) % ALL_SCHEMES.length]);
    }

    private readInitial(): ColorScheme {
        if (!this.isBrowser) {
            return DEFAULT_SCHEME;
        }
        try {
            const stored = localStorage.getItem(STORAGE_KEY);
            return isColorScheme(stored) ? stored : DEFAULT_SCHEME;
        } catch {
            return DEFAULT_SCHEME;
        }
    }
}
