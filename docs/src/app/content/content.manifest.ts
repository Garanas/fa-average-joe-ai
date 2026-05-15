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
