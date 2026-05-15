import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

import { ColorSchemeToggle } from '../features/theme/color-scheme-toggle';
import { FafLink } from '../features/theme/faf-link';
import { ThemeSwitcher } from '../features/theme/theme-switcher';

@Component({
    selector: 'app-root',
    imports: [RouterOutlet, RouterLink, ThemeSwitcher, ColorSchemeToggle, FafLink],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './app.html',
    host: { class: 'block' }
})
export class App {}
