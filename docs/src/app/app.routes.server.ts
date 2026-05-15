import { RenderMode, ServerRoute } from '@angular/ssr';

import { DOC_ENTRIES } from './content/content.manifest';

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
        path: '**',
        renderMode: RenderMode.Prerender
    }
];
