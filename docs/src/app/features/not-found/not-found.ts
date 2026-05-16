import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
    selector: 'app-not-found',
    imports: [RouterLink],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <article class="mx-auto max-w-3xl px-6 pt-16 pb-16 text-center">
            <p class="font-display text-xs font-semibold uppercase tracking-[0.18em] text-accent">
                404
            </p>
            <h1 class="mt-3 font-display text-4xl font-semibold tracking-tight">
                Commander not found
            </h1>
            <p class="mt-4 text-muted">
                The commander you were looking for has moved or recalled, all intel is lost.
            </p>
            <a
                class="mt-8 inline-block rounded-lg border border-border px-4 py-2 text-sm font-medium text-text no-underline hover:border-accent hover:text-accent"
                routerLink="/"
            >
                &larr; Back to the base
            </a>
        </article>
    `,
    host: { class: 'block' }
})
export class NotFound {}
