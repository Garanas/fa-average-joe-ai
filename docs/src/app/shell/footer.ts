import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
    selector: 'app-footer',
    standalone: true,
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `<small>Average Joe AI &mdash; documentation</small>`,
    host: {
        class: 'border-t border-border px-6 py-4 text-center text-muted',
        role: 'contentinfo'
    }
})
export class Footer {}
