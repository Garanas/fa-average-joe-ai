import { Injectable, PLATFORM_ID, effect, inject, signal } from '@angular/core';
import { Location, isPlatformBrowser } from '@angular/common';

import { DEFAULT_FACTION, FACTIONS, type FactionId, isFactionId } from './faction-theme';

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
    /** True if only some factions ship this asset; see `OUTER_BORDER_FACTIONS`. */
    outer?: boolean;
}

/**
 * Factions that ship the `/minimap-outer-border/` texture set. Aeon shipped
 * first; add the others here as their assets land. When the set covers every
 * faction, this can collapse back to "always apply".
 */
const OUTER_BORDER_FACTIONS: ReadonlySet<FactionId> = new Set<FactionId>(['aeon']);

/**
 * Browser-tab favicons. Each faction's `/factions/<id>/favicons/` folder
 * contains the same filenames, so swapping the active faction means rewriting
 * the `href` on these <link> elements — the relative paths stay constant.
 *
 * The `site.webmanifest` is intentionally omitted: its internal icon paths
 * differ per faction and runtime manifest swaps are unreliable across
 * browsers. PWA install icons remain the build-time defaults.
 */
interface FaviconLink {
    rel: string;
    type: string;
    file: string;
    sizes?: string;
}

const FAVICON_LINKS: readonly FaviconLink[] = [
    { rel: 'icon', type: 'image/x-icon', file: 'favicon.ico' },
    { rel: 'icon', type: 'image/png', file: 'favicon-32x32.png', sizes: '32x32' },
    { rel: 'icon', type: 'image/png', file: 'favicon-16x16.png', sizes: '16x16' },
    { rel: 'apple-touch-icon', type: 'image/png', file: 'apple-touch-icon.png' },
];

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
    { property: '--bracket-right-b', path: '/bracket-right/bracket_bmp_b.png' },

    /* Outer frame textures (header-bar variant). Aeon ships these today; the   */
    /* other factions will get the same `/minimap-outer-border/` folder later.  */
    /* Missing files just resolve to a 404 and the corresponding piece renders  */
    /* as nothing — same graceful fallback the inner frame already relies on.   */
    {
        property: '--outer-frame-ul',
        path: '/minimap-outer-border/mini-map_brd_ul.png',
        outer: true,
    },
    {
        property: '--outer-frame-ur',
        path: '/minimap-outer-border/mini-map_brd_ur.png',
        outer: true,
    },
    {
        property: '--outer-frame-ll',
        path: '/minimap-outer-border/mini-map_brd_ll.png',
        outer: true,
    },
    {
        property: '--outer-frame-lr',
        path: '/minimap-outer-border/mini-map_brd_lr.png',
        outer: true,
    },
    {
        property: '--outer-frame-top',
        path: '/minimap-outer-border/mini-map_brd_horz_um.png',
        outer: true,
    },
    {
        property: '--outer-frame-bottom',
        path: '/minimap-outer-border/mini-map_brd_lm.png',
        outer: true,
    },
    {
        property: '--outer-frame-left',
        path: '/minimap-outer-border/mini-map_brd_vert_l.png',
        outer: true,
    },
    {
        property: '--outer-frame-right',
        path: '/minimap-outer-border/mini-map_brd_vert_r.png',
        outer: true,
    },
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
        const hasOuter = OUTER_BORDER_FACTIONS.has(faction);
        for (const { property, path, outer } of FRAME_ASSETS) {
            if (outer && !hasOuter) {
                /* Skip outer-frame URLs for factions that haven't shipped the */
                /* `/minimap-outer-border/` assets yet — otherwise the browser */
                /* would log a 404 per piece on every theme change. The CSS    */
                /* falls back to `none` via `var(--outer-frame-ul, none)`.     */
                root.style.removeProperty(property);
                continue;
            }
            const href = this.location.prepareExternalUrl(`/factions/${faction}${path}`);
            root.style.setProperty(property, `url("${href}")`);
        }
    }

    /**
     * Point the page's favicon <link>s at the active faction's
     * `favicons/` folder. Each `FAVICON_LINKS` entry is keyed by its
     * `rel` (plus `sizes`, where present) so the same <link> is reused
     * across swaps instead of accumulating duplicates.
     */
    private applyFavicon(faction: FactionId): void {
        const head = document.head;
        for (const { rel, type, file, sizes } of FAVICON_LINKS) {
            const selector = sizes
                ? `link[rel="${rel}"][sizes="${sizes}"]`
                : `link[rel="${rel}"]:not([sizes])`;
            let link = head.querySelector<HTMLLinkElement>(selector);
            if (!link) {
                link = document.createElement('link');
                link.rel = rel;
                if (sizes) {
                    /* setAttribute over link.sizes.add(): the latter mutates a    */
                    /* DOMTokenList that isn't populated on freshly-created        */
                    /* HTMLLinkElement in jsdom/happy-dom, breaking unit tests.    */
                    link.setAttribute('sizes', sizes);
                }
                head.appendChild(link);
            }
            link.type = type;
            link.href = this.location.prepareExternalUrl(`/factions/${faction}/favicons/${file}`);
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
