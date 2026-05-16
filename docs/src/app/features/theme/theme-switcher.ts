import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { ConnectedPosition, OverlayModule } from '@angular/cdk/overlay';

import { ColorScheme, ColorSchemeService } from './color-scheme.service';
import { FACTIONS } from './faction-theme';
import { ThemeService } from './theme.service';

interface SchemeOption {
    id: ColorScheme;
    label: string;
    icon: string;
}

const SCHEMES: readonly SchemeOption[] = [
    { id: 'light', label: 'Light theme', icon: 'light_mode' },
    { id: 'dark', label: 'Dark theme', icon: 'dark_mode' },
    { id: 'auto', label: 'Auto (system)', icon: 'brightness_auto' },
];

/**
 * Anchor the overlay's right edge under the trigger's right edge.
 * Falls back to opening upward if there's no room below.
 */
const OVERLAY_POSITIONS: ConnectedPosition[] = [
    {
        originX: 'end',
        originY: 'bottom',
        overlayX: 'end',
        overlayY: 'top',
        offsetY: 8,
    },
    {
        originX: 'end',
        originY: 'top',
        overlayX: 'end',
        overlayY: 'bottom',
        offsetY: -8,
    },
];

@Component({
    selector: 'app-theme-switcher',
    imports: [MatButtonModule, MatIconModule, OverlayModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <button
            mat-icon-button
            cdkOverlayOrigin
            #trigger="cdkOverlayOrigin"
            type="button"
            (click)="toggle()"
            [attr.aria-expanded]="open()"
            aria-haspopup="dialog"
            aria-label="Theme settings"
            title="Theme settings (Ctrl + ← / → to cycle factions)"
        >
            <mat-icon class="text-text">palette</mat-icon>
        </button>
        <ng-template
            cdkConnectedOverlay
            [cdkConnectedOverlayOrigin]="trigger"
            [cdkConnectedOverlayOpen]="open()"
            [cdkConnectedOverlayPositions]="positions"
            [cdkConnectedOverlayHasBackdrop]="true"
            cdkConnectedOverlayBackdropClass="cdk-overlay-transparent-backdrop"
            (backdropClick)="close()"
        >
            <div
                class="theme-switcher__panel flex flex-row gap-3 rounded-xl border border-border bg-surface p-3 text-text"
                role="dialog"
                aria-label="Theme settings"
            >
                <section class="flex flex-col gap-1">
                    <h3 class="theme-switcher__section-title">Faction</h3>
                    <div class="flex flex-col gap-1">
                        @for (faction of factions; track faction.id) {
                            <button
                                mat-icon-button
                                type="button"
                                [class.is-active]="faction.id === theme.current()"
                                [attr.aria-label]="faction.label"
                                [title]="faction.label"
                                (click)="theme.setTheme(faction.id)"
                            >
                                <mat-icon
                                    [class]="'faction-icon-' + faction.id"
                                    [svgIcon]="'factions:' + faction.id"
                                />
                            </button>
                        }
                    </div>
                </section>
                <section class="flex flex-col gap-1">
                    <h3 class="theme-switcher__section-title">Theme</h3>
                    <div class="flex flex-row gap-1">
                        @for (scheme of schemes; track scheme.id) {
                            <button
                                mat-icon-button
                                type="button"
                                [class.is-active]="scheme.id === colorScheme.current()"
                                [attr.aria-label]="scheme.label"
                                [title]="scheme.label"
                                (click)="colorScheme.setScheme(scheme.id)"
                            >
                                <mat-icon>{{ scheme.icon }}</mat-icon>
                            </button>
                        }
                    </div>
                </section>
            </div>
        </ng-template>
    `,
    styles: [
        `
            /* Multi-layer drop shadow — Tailwind doesn't have a preset that  */
            /* matches the close-soft + far-prominent pair we want for a      */
            /* popover surface. Everything else on the panel is utility-driven. */
            .theme-switcher__panel {
                box-shadow:
                    0 4px 6px rgba(0, 0, 0, 0.04),
                    0 10px 32px rgba(0, 0, 0, 0.18);
            }

            /* Reused in two places — extracted so the five small declarations */
            /* aren't duplicated as utility class lists on both <h3>s.         */
            .theme-switcher__section-title {
                margin: 0 0 4px;
                padding: 0 4px;
                font-size: 0.6875rem;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                color: var(--color-muted);
            }

            /* Active button uses Material's secondary-container token, which */
            /* is overridden per-faction via the .theme-* class on <html>.   */
            /* That makes the active chip tint with the current faction.    */
            button.is-active {
                background-color: var(--mat-sys-secondary-container);
                color: var(--mat-sys-on-secondary-container);
            }
        `,
    ],
    host: {
        class: 'inline-block',
        '(document:keydown.escape)': 'onEscape()',
        '(document:keydown)': 'onDocumentKeydown($event)',
    },
})
export class ThemeSwitcher {
    protected readonly theme = inject(ThemeService);
    protected readonly colorScheme = inject(ColorSchemeService);

    protected readonly open = signal(false);

    protected readonly factions = FACTIONS;
    protected readonly schemes = SCHEMES;
    protected readonly positions = OVERLAY_POSITIONS;

    protected toggle(): void {
        this.open.update((v) => !v);
    }

    protected close(): void {
        this.open.set(false);
    }

    /** Esc closes the overlay when open. */
    protected onEscape(): void {
        if (this.open()) {
            this.close();
        }
    }

    /**
     * Global Ctrl + ←/→ cycles through factions. Skipped when the user is
     * typing in a text field so we don't fight word-jump shortcuts.
     */
    protected onDocumentKeydown(event: KeyboardEvent): void {
        if (!event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) {
            return;
        }
        if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
            return;
        }
        const target = event.target as HTMLElement | null;
        if (target?.matches('input, textarea, [contenteditable=""], [contenteditable="true"]')) {
            return;
        }
        event.preventDefault();
        this.theme.cycle(event.key === 'ArrowLeft' ? -1 : 1);
    }
}
