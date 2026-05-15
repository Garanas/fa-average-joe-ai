import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Location } from '@angular/common';

import { findFaction } from '../theme/faction-theme';
import { ThemeService } from '../theme/theme.service';

@Component({
    selector: 'app-hero-banner',
    standalone: true,
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <section class="hero-banner overflow-hidden rounded-2xl border border-border">
            <div class="relative flex items-center gap-6 px-8 py-10 sm:px-12 sm:py-14">
                <div class="relative z-10 max-w-xl">
                    <p class="font-display text-xs font-semibold uppercase tracking-[0.18em] text-accent">
                        {{ faction().hero.eyebrow }}
                    </p>
                    <h1 class="mt-2 font-display text-3xl font-bold leading-tight tracking-tight sm:text-4xl">
                        {{ faction().hero.title }}
                    </h1>
                    <p class="mt-4 text-base leading-relaxed text-muted sm:text-[1.0625rem]">
                        {{ faction().hero.tagline }}
                    </p>
                </div>
                <img
                    class="hero-banner__icon pointer-events-none absolute -right-6 -bottom-6 hidden h-56 w-56 select-none sm:block"
                    [src]="iconUrl()"
                    alt=""
                />
            </div>
        </section>
    `,
    styles: [
        `
            .hero-banner {
                position: relative;
                background:
                    radial-gradient(
                        circle at 100% 0%,
                        color-mix(in srgb, var(--color-accent) 22%, transparent) 0%,
                        transparent 55%
                    ),
                    linear-gradient(
                        135deg,
                        color-mix(in srgb, var(--color-accent) 6%, var(--color-surface)) 0%,
                        var(--color-surface) 60%
                    );
            }

            .hero-banner__icon {
                opacity: 0.18;
                filter: drop-shadow(0 0 28px color-mix(in srgb, var(--color-accent) 60%, transparent));
            }
        `
    ],
    host: { class: 'block' }
})
export class HeroBanner {
    private readonly theme = inject(ThemeService);
    private readonly location = inject(Location);

    protected readonly faction = computed(() => findFaction(this.theme.current()));
    protected readonly iconUrl = computed(() =>
        this.location.prepareExternalUrl(this.faction().iconPath)
    );
}
