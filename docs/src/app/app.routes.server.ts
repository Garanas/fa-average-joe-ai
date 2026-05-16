import { RenderMode, ServerRoute } from '@angular/ssr';

import { DOC_CATEGORIES, DOC_ENTRIES } from './features/docs/content.manifest';

export const serverRoutes: ServerRoute[] = [
    {
        path: '',
        renderMode: RenderMode.Prerender
    },
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
        /* SSR (not prerender) so we can return a real HTTP 404 for unknown    */
        /* URLs. RenderMode.Prerender would have to enumerate every possible   */
        /* miss via getPrerenderParams and would emit 200 OK regardless.       */
        path: '**',
        renderMode: RenderMode.Server,
        status: 404
    }
];
