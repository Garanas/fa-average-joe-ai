import { Injectable, PLATFORM_ID, effect, inject, signal } from '@angular/core';
import { Location, isPlatformBrowser } from '@angular/common';

import { DEFAULT_FACTION, FACTIONS, FactionId, findFaction, isFactionId } from './faction-theme';

const STORAGE_KEY = 'fa-joe-ai-faction-theme';

/**
 * Custom-property names + their texture paths within /factions/<id>/.
 * The directory structure and filenames are identical per faction, so
 * dropping a new faction's textures into the same paths is all it takes.
 */
interface FrameAsset {
    property: string;
    /** Path under /factions/<id>/, with leading slash. */
    path: string;
}

const FRAME_ASSETS: readonly FrameAsset[] = [
    { property: '--frame-ul', path: '/minimap-border/mini-map-glow_brd_ul.png' },
    { property: '--frame-ur', path: '/minimap-border/mini-map-glow_brd_ur.png' },
    { property: '--frame-ll', path: '/minimap-border/mini-map-glow_brd_ll.png' },
    { property: '--frame-lr', path: '/minimap-border/mini-map-glow_brd_lr.png' },
    { property: '--frame-top', path: '/minimap-border/mini-map-glow_brd_horz_um.png' },
    { property: '--frame-bottom', path: '/minimap-border/mini-map-glow_brd_lm.png' },
    { property: '--frame-left', path: '/minimap-border/mini-map-glow_brd_vert_l.png' },
    { property: '--frame-right', path: '/minimap-border/mini-map-glow_brd_vert_r.png' },
    { property: '--bracket-left-t', path: '/bracket-left/bracket_bmp_t.png' },
    { property: '--bracket-left-m', path: '/bracket-left/bracket_bmp_m.png' },
    { property: '--bracket-left-b', path: '/bracket-left/bracket_bmp_b.png' },
    { property: '--bracket-right-t', path: '/bracket-right/bracket_bmp_t.png' },
    { property: '--bracket-right-m', path: '/bracket-right/bracket_bmp_m.png' },
    { property: '--bracket-right-b', path: '/bracket-right/bracket_bmp_b.png' }
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
            this.applyFavicon(active);
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

    /** Move to the next or previous faction in the list, wrapping around. */
    cycle(direction: 1 | -1): void {
        const idx = FACTIONS.findIndex((f) => f.id === this.current());
        const next = (idx + direction + FACTIONS.length) % FACTIONS.length;
        this.current.set(FACTIONS[next].id);
    }

    /**
     * Set the `--frame-*` custom properties on <html> so the FactionFrame's
     * grid cells point at the active faction's texture pieces. URLs go through
     * Location.prepareExternalUrl so they respect the build's base href.
     */
    private applyFrameAssets(faction: FactionId): void {
        const root = document.documentElement;
        for (const { property, path } of FRAME_ASSETS) {
            const href = this.location.prepareExternalUrl(`/factions/${faction}${path}`);
            root.style.setProperty(property, `url("${href}")`);
        }
    }

    /**
     * Swap the page favicon to the active faction's icon. Reuses the
     * `iconPath` already exposed by `FactionTheme`, so adding a faction means
     * dropping in the icon file and nothing else here.
     */
    private applyFavicon(faction: FactionId): void {
        const href = this.location.prepareExternalUrl(findFaction(faction).iconPath);
        let link = document.head.querySelector<HTMLLinkElement>('link[rel~="icon"]');
        if (!link) {
            link = document.createElement('link');
            link.rel = 'icon';
            document.head.appendChild(link);
        }
        link.type = 'image/png';
        link.href = href;
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
