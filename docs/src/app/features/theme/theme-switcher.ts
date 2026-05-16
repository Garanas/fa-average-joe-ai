import {
    ChangeDetectionStrategy,
    Component,
    HostListener,
    computed,
    inject,
    signal
} from '@angular/core';
import { Location } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { ConnectedPosition, OverlayModule } from '@angular/cdk/overlay';

import { ColorScheme, ColorSchemeService } from './color-scheme.service';
import { FACTIONS, FactionTheme } from './faction-theme';
import { ThemeService } from './theme.service';

interface ResolvedFaction extends FactionTheme {
    resolvedIcon: string;
}

interface SchemeOption {
    id: ColorScheme;
    label: string;
    icon: string;
}

const SCHEMES: readonly SchemeOption[] = [
    { id: 'light', label: 'Light theme', icon: 'light_mode' },
    { id: 'dark', label: 'Dark theme', icon: 'dark_mode' },
    { id: 'auto', label: 'Auto (system)', icon: 'brightness_auto' }
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
        offsetY: 8
    },
    {
        originX: 'end',
        originY: 'top',
        overlayX: 'end',
        overlayY: 'bottom',
        offsetY: -8
    }
];

@Component({
    selector: 'app-theme-switcher',
    standalone: true,
    imports: [MatButtonModule, OverlayModule],
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
            <span class="material-symbols-outlined text-text">palette</span>
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
            <div class="theme-switcher__panel" role="dialog" aria-label="Theme settings">
                <section class="theme-switcher__section">
                    <h3 class="theme-switcher__section-title">Faction</h3>
                    <div class="theme-switcher__factions">
                        @for (faction of factions(); track faction.id) {
                            <button
                                mat-button
                                type="button"
                                class="theme-switcher__faction"
                                [class.is-active]="faction.id === theme.current()"
                                (click)="theme.setTheme(faction.id)"
                            >
                                <span class="theme-switcher__faction-row">
                                    <img class="theme-switcher__faction-icon" [src]="faction.resolvedIcon" alt="" />
                                    <span>{{ faction.label }}</span>
                                </span>
                            </button>
                        }
                    </div>
                </section>
                <section class="theme-switcher__section">
                    <h3 class="theme-switcher__section-title">Theme</h3>
                    <div class="theme-switcher__schemes">
                        @for (scheme of schemes; track scheme.id) {
                            <button
                                mat-icon-button
                                type="button"
                                class="theme-switcher__scheme"
                                [class.is-active]="scheme.id === colorScheme.current()"
                                [attr.aria-label]="scheme.label"
                                [title]="scheme.label"
                                (click)="colorScheme.setScheme(scheme.id)"
                            >
                                <span class="material-symbols-outlined">{{ scheme.icon }}</span>
                            </button>
                        }
                    </div>
                </section>
            </div>
        </ng-template>
    `,
    styles: [
        `
            /* Chrome uses our own light/dark tokens (driven by data-color-     */
            /* scheme on <html>) rather than Material's --mat-sys-* tokens,    */
            /* because the magenta-violet prebuilt CSS is hard-coded dark.     */
            .theme-switcher__panel {
                display: flex;
                flex-direction: row;
                gap: 12px;
                padding: 12px;
                background-color: var(--color-surface);
                color: var(--color-text);
                border: 1px solid var(--color-border);
                border-radius: 12px;
                box-shadow:
                    0 4px 6px rgba(0, 0, 0, 0.04),
                    0 10px 32px rgba(0, 0, 0, 0.18);
            }
            .theme-switcher__section {
                display: flex;
                flex-direction: column;
                gap: 4px;
            }
            .theme-switcher__section-title {
                margin: 0 0 4px;
                padding: 0 4px;
                font-size: 0.6875rem;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                color: var(--color-muted);
            }
            .theme-switcher__factions {
                display: flex;
                flex-direction: column;
                gap: 4px;
                min-width: 10rem;
            }
            .theme-switcher__schemes {
                display: flex;
                flex-direction: row;
                gap: 4px;
            }
            .theme-switcher__faction.mat-mdc-button {
                min-width: 0;
                justify-content: flex-start;
            }
            /* Force the icon + label onto one row, since mat-button's internal */
            /* label wrapper doesn't guarantee row layout for arbitrary content. */
            .theme-switcher__faction-row {
                display: inline-flex;
                align-items: center;
                gap: 0.5rem;
                width: 100%;
            }
            .theme-switcher__faction-icon {
                display: inline-block;
                width: 1.25rem;
                height: 1.25rem;
                flex-shrink: 0;
            }
            button.is-active {
                background-color: var(--mat-sys-secondary-container);
                color: var(--mat-sys-on-secondary-container);
            }
        `
    ],
    host: { class: 'inline-block' }
})
export class ThemeSwitcher {
    protected readonly theme = inject(ThemeService);
    protected readonly colorScheme = inject(ColorSchemeService);
    private readonly location = inject(Location);

    protected readonly open = signal(false);

    protected readonly factions = computed<ResolvedFaction[]>(() =>
        FACTIONS.map((faction) => ({
            ...faction,
            resolvedIcon: this.location.prepareExternalUrl(faction.iconPath)
        }))
    );

    protected readonly schemes = SCHEMES;
    protected readonly positions = OVERLAY_POSITIONS;

    protected toggle(): void {
        this.open.update((v) => !v);
    }

    protected close(): void {
        this.open.set(false);
    }

    /** Esc closes the overlay when open. */
    @HostListener('document:keydown.escape')
    onEscape(): void {
        if (this.open()) {
            this.close();
        }
    }

    /**
     * Global Ctrl + ←/→ cycles through factions. Skipped when the user is
     * typing in a text field so we don't fight word-jump shortcuts.
     */
    @HostListener('document:keydown', ['$event'])
    onDocumentKeydown(event: KeyboardEvent): void {
        if (!event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) {
            return;
        }
        if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
            return;
        }
        const target = event.target as HTMLElement | null;
        if (
            target?.matches('input, textarea, [contenteditable=""], [contenteditable="true"]')
        ) {
            return;
        }
        event.preventDefault();
        this.theme.cycle(event.key === 'ArrowLeft' ? -1 : 1);
    }
}
