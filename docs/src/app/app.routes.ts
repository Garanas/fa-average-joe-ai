import { type Routes } from '@angular/router';

export const routes: Routes = [
    {
        path: '',
        pathMatch: 'full',
        loadComponent: () => import('./features/home/home').then((m) => m.Home),
        title: 'fa-joe-ai docs',
    },
    {
        path: 'docs/:category/:slug',
        loadComponent: () => import('./features/docs/doc-page').then((m) => m.DocPage),
    },
    {
        path: 'docs/:category',
        loadComponent: () =>
            import('./features/docs/category-overview').then((m) => m.CategoryOverview),
    },
    {
        path: '**',
        loadComponent: () => import('./features/not-found/not-found').then((m) => m.NotFound),
        title: 'Page not found · fa-joe-ai docs',
    },
];
