import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

@Component({
    selector: 'app-root',
    imports: [RouterOutlet, RouterLink],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './app.html',
    styleUrl: './app.css'
})
export class App {}
