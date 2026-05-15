import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { Header } from './header';
import { Footer } from './footer';

@Component({
    selector: 'app-root',
    imports: [RouterOutlet, Header, Footer],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './app.html',
    host: { class: 'block' }
})
export class App {}
