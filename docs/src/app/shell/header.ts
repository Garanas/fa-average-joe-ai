import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ColorSchemeToggle } from '../features/theme/color-scheme-toggle';
import { FafLink } from '../features/theme/faf-link';
import { ThemeSwitcher } from '../features/theme/theme-switcher';

@Component({
    selector: 'app-header',
    standalone: true,
    imports: [RouterLink, ThemeSwitcher, ColorSchemeToggle, FafLink],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <a
            class="font-display text-lg font-semibold tracking-tight text-text no-underline"
            routerLink="/"
        >
            fa-joe-ai
        </a>
        <div class="flex items-center gap-2">
            <app-theme-switcher />
            <app-color-scheme-toggle />
            <app-faf-link />
        </div>
    `,
    host: {
        class: 'flex items-center justify-between gap-4 border-b border-border bg-surface px-6 py-3',
        role: 'banner'
    }
})
export class Header {}
