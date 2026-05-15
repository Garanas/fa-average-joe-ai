import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Location } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';

@Component({
    selector: 'app-faf-link',
    standalone: true,
    imports: [MatButtonModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <a
            mat-icon-button
            href="https://www.faforever.com/"
            target="_blank"
            rel="noopener"
            aria-label="Visit FAForever"
            title="Visit FAForever"
        >
            <img class="h-6 w-6" [src]="iconUrl()" alt="" />
        </a>
    `,
    host: { class: 'inline-block' }
})
export class FafLink {
    private readonly location = inject(Location);
    protected readonly iconUrl = computed(() =>
        this.location.prepareExternalUrl('/factions/icon-faf.svg')
    );
}
