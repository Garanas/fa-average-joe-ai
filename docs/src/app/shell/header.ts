import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ThemeSwitcher } from '../features/theme/theme-switcher';

@Component({
    selector: 'app-header',
    imports: [RouterLink, ThemeSwitcher],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <a
            class="font-display text-lg font-semibold tracking-tight text-text no-underline"
            routerLink="/"
        >
            Average Joe AI
        </a>
        <app-theme-switcher />
    `,
    host: {
        class: 'flex items-center justify-between gap-4 border-b border-border bg-surface px-6 py-3',
        role: 'banner'
    }
})
export class Header {}
