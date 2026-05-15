import { Injectable, PLATFORM_ID, effect, inject, signal } from '@angular/core';
import { Location, isPlatformBrowser } from '@angular/common';

import { DEFAULT_FACTION, FACTIONS, FactionId, isFactionId } from './faction-theme';

const STORAGE_KEY = 'fa-joe-ai-faction-theme';

/**
 * Custom-property names + their corresponding texture filenames inside
 * /factions/<id>/minimap-border/. The pattern is identical per faction, so
 * dropping a new faction's textures into that path is all it takes.
 */
const FRAME_ASSETS: readonly { property: string; file: string }[] = [
    { property: '--frame-ul', file: 'mini-map-glow_brd_ul.png' },
    { property: '--frame-ur', file: 'mini-map-glow_brd_ur.png' },
    { property: '--frame-ll', file: 'mini-map-glow_brd_ll.png' },
    { property: '--frame-lr', file: 'mini-map-glow_brd_lr.png' },
    { property: '--frame-top', file: 'mini-map-glow_brd_horz_um.png' },
    { property: '--frame-bottom', file: 'mini-map-glow_brd_lm.png' },
    { property: '--frame-left', file: 'mini-map-glow_brd_vert_l.png' },
    { property: '--frame-right', file: 'mini-map-glow_brd_vert_r.png' }
];

@Injectable({ providedIn: 'root' })
export class ThemeService {
    private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));
    private readonly location = inject(Location);

    readonly current = signal<FactionId>(this.readInitial());

    constructor() {
        if (!this.isBrowser) {
            return;
        }
        effect(() => {
            const active = this.current();
            const root = document.documentElement;
            const classList = root.classList;
            for (const faction of FACTIONS) {
                classList.toggle(`theme-${faction.id}`, faction.id === active);
            }
            this.applyFrameAssets(active);
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

    /**
     * Set the `--frame-*` custom properties on <html> so the FactionFrame's
     * grid cells point at the active faction's texture pieces. URLs go through
     * Location.prepareExternalUrl so they respect the build's base href.
     */
    private applyFrameAssets(faction: FactionId): void {
        const root = document.documentElement;
        for (const { property, file } of FRAME_ASSETS) {
            const href = this.location.prepareExternalUrl(
                `/factions/${faction}/minimap-border/${file}`
            );
            root.style.setProperty(property, `url("${href}")`);
        }
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
