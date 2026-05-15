import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Location } from '@angular/common';
import { MatSelectChange, MatSelectModule } from '@angular/material/select';
import { MatFormFieldModule } from '@angular/material/form-field';

import { FACTIONS, FactionId, FactionTheme } from './faction-theme';
import { ThemeService } from './theme.service';

interface ResolvedFaction extends FactionTheme {
    resolvedIcon: string;
}

@Component({
    selector: 'app-theme-switcher',
    standalone: true,
    imports: [MatSelectModule, MatFormFieldModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <mat-form-field appearance="outline" subscriptSizing="dynamic" class="theme-switcher-field">
            <mat-label>Faction</mat-label>
            <mat-select [value]="theme.current()" (selectionChange)="onChange($event)" panelWidth="auto">
                @for (faction of factions(); track faction.id) {
                    <mat-option [value]="faction.id">
                        <span class="flex items-center gap-2">
                            <img class="h-5 w-5" [src]="faction.resolvedIcon" alt="" />
                            <span>{{ faction.label }}</span>
                        </span>
                    </mat-option>
                }
            </mat-select>
        </mat-form-field>
    `,
    styles: [
        `
            .theme-switcher-field {
                width: 11rem;
            }
        `
    ],
    host: { class: 'inline-block' }
})
export class ThemeSwitcher {
    protected readonly theme = inject(ThemeService);
    private readonly location = inject(Location);

    protected readonly factions = computed<ResolvedFaction[]>(() =>
        FACTIONS.map((faction) => ({
            ...faction,
            resolvedIcon: this.location.prepareExternalUrl(faction.iconPath)
        }))
    );

    protected onChange(event: MatSelectChange): void {
        this.theme.setTheme(event.value as FactionId);
    }
}
