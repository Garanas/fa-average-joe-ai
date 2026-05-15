import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';

import { ColorSchemeService } from './color-scheme.service';

const ICONS: Record<'light' | 'dark' | 'auto', string> = {
    light: 'light_mode',
    dark: 'dark_mode',
    auto: 'brightness_auto'
};

const LABELS: Record<'light' | 'dark' | 'auto', string> = {
    light: 'Light theme (click for dark)',
    dark: 'Dark theme (click for auto)',
    auto: 'Auto theme (click for light)'
};

@Component({
    selector: 'app-color-scheme-toggle',
    standalone: true,
    imports: [MatButtonModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <button
            mat-icon-button
            type="button"
            [attr.aria-label]="label()"
            [title]="label()"
            (click)="scheme.cycle()"
        >
            <span class="material-symbols-outlined">{{ icon() }}</span>
        </button>
    `,
    host: { class: 'inline-block' }
})
export class ColorSchemeToggle {
    protected readonly scheme = inject(ColorSchemeService);
    protected readonly icon = computed(() => ICONS[this.scheme.current()]);
    protected readonly label = computed(() => LABELS[this.scheme.current()]);
}
