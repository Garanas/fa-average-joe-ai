import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { HeroBanner } from '../theme/hero-banner';
import { recentByCategory } from '../docs/content.manifest';

const PREVIEW_LIMIT = 2;

@Component({
    selector: 'app-home',
    imports: [RouterLink, HeroBanner],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './home.html',
    host: { class: 'block' }
})
export class Home {
    protected readonly groups = recentByCategory(PREVIEW_LIMIT);
}
