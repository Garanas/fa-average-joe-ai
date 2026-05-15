import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { HeroBanner } from '../hero-banner/hero-banner';
import { docsByCategory } from '../content/content.manifest';

@Component({
    selector: 'app-home',
    standalone: true,
    imports: [RouterLink, HeroBanner],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './home.html',
    host: { class: 'block' }
})
export class Home {
    protected readonly groups = docsByCategory();
}
