import {
    type ApplicationConfig,
    inject,
    provideAppInitializer,
    provideBrowserGlobalErrorListeners,
    provideZonelessChangeDetection,
} from '@angular/core';
import { provideRouter, withInMemoryScrolling } from '@angular/router';
import { provideHttpClient, withFetch } from '@angular/common/http';
import { DomSanitizer, provideClientHydration, withEventReplay } from '@angular/platform-browser';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { Location } from '@angular/common';
import { MatIconRegistry } from '@angular/material/icon';
import { MARKED_OPTIONS, provideMarkdown } from 'ngx-markdown';

import { routes } from './app.routes';
import { FACTIONS } from './features/theme/faction-theme';

export const appConfig: ApplicationConfig = {
    providers: [
        provideZonelessChangeDetection(),
        provideBrowserGlobalErrorListeners(),
        provideRouter(
            routes,
            withInMemoryScrolling({ scrollPositionRestoration: 'top', anchorScrolling: 'enabled' }),
        ),
        provideClientHydration(withEventReplay()),
        provideHttpClient(withFetch()),
        provideAnimationsAsync(),
        provideMarkdown({
            markedOptions: {
                provide: MARKED_OPTIONS,
                useValue: {
                    gfm: true,
                    breaks: false,
                    pedantic: false,
                },
            },
        }),
        /* Register each faction SVG under the "factions" namespace so any */
        /* component can render <mat-icon svgIcon="factions:uef"> etc.    */
        /* without re-fetching. URLs go through Location.prepareExternalUrl */
        /* so they respect the build's base href.                          */
        provideAppInitializer(() => {
            const registry = inject(MatIconRegistry);
            const sanitizer = inject(DomSanitizer);
            const location = inject(Location);
            /* Make <mat-icon>name</mat-icon> use Material Symbols ligatures by */
            /* default, so callers don't have to set fontSet on every usage and */
            /* mat-icon-button's alignment CSS (which targets .mat-icon) kicks  */
            /* in for the icon glyphs.                                          */
            registry.setDefaultFontSetClass('material-symbols-outlined');
            for (const faction of FACTIONS) {
                registry.addSvgIconInNamespace(
                    'factions',
                    faction.id,
                    sanitizer.bypassSecurityTrustResourceUrl(
                        location.prepareExternalUrl(`/factions/${faction.id}/icon.svg`),
                    ),
                );
            }
        }),
    ],
};
