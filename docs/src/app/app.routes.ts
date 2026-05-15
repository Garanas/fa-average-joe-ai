import { Routes } from '@angular/router';

export const routes: Routes = [
    {
        path: '',
        pathMatch: 'full',
        loadComponent: () => import('./home/home').then((m) => m.Home),
        title: 'fa-joe-ai docs'
    },
    {
        path: 'docs/:category/:slug',
        loadComponent: () => import('./doc-page/doc-page').then((m) => m.DocPage)
    },
    {
        path: '**',
        loadComponent: () => import('./home/home').then((m) => m.Home)
    }
];
