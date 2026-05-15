import { RenderMode, ServerRoute } from '@angular/ssr';

import { DOC_CATEGORIES, DOC_ENTRIES } from './features/docs/content.manifest';

export const serverRoutes: ServerRoute[] = [
    {
        path: 'docs/:category/:slug',
        renderMode: RenderMode.Prerender,
        getPrerenderParams: async () =>
            DOC_ENTRIES.map((entry) => ({
                category: entry.category,
                slug: entry.slug
            }))
    },
    {
        path: 'docs/:category',
        renderMode: RenderMode.Prerender,
        getPrerenderParams: async () =>
            DOC_CATEGORIES.map((category) => ({ category: category.id }))
    },
    {
        path: '**',
        renderMode: RenderMode.Prerender
    }
];
