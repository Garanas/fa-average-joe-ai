export interface DocCategory {
    id: string;
    label: string;
    order: number;
    sort: 'manual' | 'newest-first';
}

export interface ReleaseEmbedSpec {
    /** Tag name to fetch, or omit for the repository's latest release. */
    tag?: string;
}

export interface DocEntry {
    category: string;
    slug: string;
    title: string;
    summary?: string;
    file: string;
    order: number;
    /** ISO date string (YYYY-MM-DD). Required for blog posts. */
    date?: string;
    author?: string;
    release?: ReleaseEmbedSpec;
}

export const DOC_CATEGORIES: readonly DocCategory[] = [
    { id: 'blog', label: 'Blog', order: 5, sort: 'newest-first' },
    { id: 'adr', label: 'Architecture Decisions', order: 10, sort: 'manual' },
    { id: 'internals', label: 'How the AI Works', order: 20, sort: 'manual' }
];

export const DOC_ENTRIES: readonly DocEntry[] = [
    // ----- Blog --------------------------------------------------------------

    {
        category: 'blog',
        slug: '2026-05-15-v0-1-release',
        title: 'v0.1 — first playable release',
        summary: 'The first tagged release is out: cleaner boot, smarter openings, and engineers that actually reclaim wrecks.',
        file: 'blog/2026-05-15-v0-1-release.md',
        order: 0,
        date: '2026-05-15',
        author: 'Jip',
        release: { tag: 'v0.1' }
    },
    {
        category: 'blog',
        slug: '2026-04-20-build-system-refactor',
        title: 'Build system refactor: from imperative to declarative',
        summary: 'Engineers used to walk through a hand-coded checklist. Now they pull jobs off a queue and the rule lives in one place.',
        file: 'blog/2026-04-20-build-system-refactor.md',
        order: 0,
        date: '2026-04-20',
        author: 'Jip'
    },

    // ----- ADRs --------------------------------------------------------------

    {
        category: 'adr',
        slug: '0001-comment-style',
        title: 'ADR 0001: Comment style',
        summary: 'Density, voice, and shape rules for prose comments in fa-joe-ai source.',
        file: 'adr/0001-comment-style.md',
        order: 1
    },
    {
        category: 'adr',
        slug: '0002-coordinator-pattern',
        title: 'ADR 0002: Coordinator pattern',
        summary: 'Why JoeBase is the only place where components meet the brain.',
        file: 'adr/0002-coordinator-pattern.md',
        order: 2
    },
    {
        category: 'adr',
        slug: '0003-faction-agnostic-chunks',
        title: 'ADR 0003: Faction-agnostic base chunks',
        summary: 'Building identifiers, not blueprint ids, so one chunk covers all factions.',
        file: 'adr/0003-faction-agnostic-chunks.md',
        order: 3
    },
    {
        category: 'adr',
        slug: '0004-theme-tokens-in-ts',
        title: 'ADR 0004: Theme tokens in TypeScript',
        summary: 'TypeScript is canonical for theme metadata; CSS holds only the colour values.',
        file: 'adr/0004-theme-tokens-in-ts.md',
        order: 4
    },

    // ----- Internals ---------------------------------------------------------

    {
        category: 'internals',
        slug: 'brain-overview',
        title: 'Brain overview',
        summary: 'What JoeBrain owns, what it does not, and how it composes grid features.',
        file: 'internals/brain-overview.md',
        order: 1
    },
    {
        category: 'internals',
        slug: 'base-lifecycle',
        title: 'Base lifecycle',
        summary: 'Spawning, settling, operational, retreating — the four phases of a JoeBase.',
        file: 'internals/base-lifecycle.md',
        order: 2
    },
    {
        category: 'internals',
        slug: 'build-site-grid',
        title: 'Build site grid',
        summary: 'How a base indexes legal placements and tracks reservation state.',
        file: 'internals/build-site-grid.md',
        order: 3
    },
    {
        category: 'internals',
        slug: 'platoon-behaviors',
        title: 'Platoon behaviors',
        summary: 'State-machine pattern for unit-level controllers, with engineer examples.',
        file: 'internals/platoon-behaviors.md',
        order: 4
    },
    {
        category: 'internals',
        slug: 'reclaim-heuristics',
        title: 'Reclaim heuristics',
        summary: 'How GridReclaim scores cells, when it refreshes, and why we skip per-wreck records.',
        file: 'internals/reclaim-heuristics.md',
        order: 5
    }
];

export function findDoc(category: string, slug: string): DocEntry | undefined {
    return DOC_ENTRIES.find((entry) => entry.category === category && entry.slug === slug);
}

export function docsByCategory(): { category: DocCategory; entries: DocEntry[] }[] {
    return DOC_CATEGORIES.map((category) => ({
        category,
        entries: sortEntries(
            category,
            DOC_ENTRIES.filter((entry) => entry.category === category.id)
        )
    })).sort((a, b) => a.category.order - b.category.order);
}

function sortEntries(category: DocCategory, entries: DocEntry[]): DocEntry[] {
    if (category.sort === 'newest-first') {
        return [...entries].sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
    }
    return [...entries].sort((a, b) => a.order - b.order);
}

export function docAssetPath(entry: DocEntry): string {
    return `/content/${entry.file}`;
}

export function docRoute(entry: DocEntry): string[] {
    return ['/', 'docs', entry.category, entry.slug];
}
