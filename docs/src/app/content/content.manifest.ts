export interface DocCategory {
    id: string;
    label: string;
    order: number;
}

export interface DocEntry {
    category: string;
    slug: string;
    title: string;
    summary?: string;
    file: string;
    order: number;
}

export const DOC_CATEGORIES: readonly DocCategory[] = [
    { id: 'adr', label: 'Architecture Decisions', order: 10 },
    { id: 'internals', label: 'How the AI Works', order: 20 }
];

export const DOC_ENTRIES: readonly DocEntry[] = [
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
        entries: DOC_ENTRIES.filter((entry) => entry.category === category.id).sort(
            (a, b) => a.order - b.order
        )
    })).sort((a, b) => a.category.order - b.category.order);
}

export function docAssetPath(entry: DocEntry): string {
    return `/content/${entry.file}`;
}

export function docRoute(entry: DocEntry): string[] {
    return ['/', 'docs', entry.category, entry.slug];
}
