import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { docsByCategory } from '../content/content.manifest';

@Component({
    selector: 'app-home',
    standalone: true,
    imports: [RouterLink],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './home.html',
    host: { class: 'block' }
})
export class Home {
    protected readonly groups = docsByCategory();
}
