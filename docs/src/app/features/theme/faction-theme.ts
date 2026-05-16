export type FactionId = 'uef' | 'cybran' | 'aeon' | 'seraphim';

export interface FactionHero {
    eyebrow: string;
    title: string;
    tagline: string;
}

export interface FactionTheme {
    id: FactionId;
    label: string;
    hero: FactionHero;
}

export const FACTIONS: readonly FactionTheme[] = [
    {
        id: 'uef',
        label: 'UEF',
        hero: {
            eyebrow: 'United Earth Federation',
            title: 'Hold the line. Build the line.',
            tagline:
                'Heavy armour, dependable engineers, and the discipline to grind any battlefield into a UEF parade ground.',
        },
    },
    {
        id: 'cybran',
        label: 'Cybran',
        hero: {
            eyebrow: 'Cybran Nation',
            title: 'Strike fast. Strike everywhere.',
            tagline:
                'Stealth, speed, and surgical reclaim — the AI that turns your opponent’s footprint into your next factory.',
        },
    },
    {
        id: 'aeon',
        label: 'Aeon',
        hero: {
            eyebrow: 'Aeon Illuminate',
            title: 'The Way is one of patience.',
            tagline:
                'Energy-rich, hover-mobile, and unrelenting. Outlast the opening, then convert the map one shrine at a time.',
        },
    },
    {
        id: 'seraphim',
        label: 'Seraphim',
        hero: {
            eyebrow: 'The Seraphim',
            title: 'Ythotha’rein. We return.',
            tagline:
                'Late-game terror and shielded behemoths. Trade tempo for unstoppable mass, then close the door behind you.',
        },
    },
];

export const DEFAULT_FACTION: FactionId = 'uef';

export function isFactionId(value: unknown): value is FactionId {
    return typeof value === 'string' && FACTIONS.some((f) => f.id === value);
}

export function findFaction(id: FactionId): FactionTheme {
    const match = FACTIONS.find((f) => f.id === id);
    if (!match) {
        throw new Error(`Unknown faction id: ${id}`);
    }
    return match;
}
