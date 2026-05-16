import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Location } from '@angular/common';

import { FactionFrame } from './faction-frame';
import { findFaction } from './faction-theme';
import { ThemeService } from './theme.service';

@Component({
    selector: 'app-hero-banner',
    standalone: true,
    imports: [FactionFrame],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <app-faction-frame>
            <div class="hero-banner relative flex items-center gap-6 px-8 py-10 sm:px-12 sm:py-14">
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
                    class="hero-banner__icon pointer-events-none absolute -right-6 -bottom-6 hidden h-56 w-56 select-none opacity-[0.18] sm:block"
                    [src]="iconUrl()"
                    alt=""
                />
            </div>
        </app-faction-frame>
    `,
    styles: [
        `
            .hero-banner {
                /* The faction frame draws the outer chrome; this gradient sits */
                /* inside it as the content background and follows the active   */
                /* faction's --color-accent.                                     */
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

            /* Only the color-mix drop-shadow stays as raw CSS — it composes a */
            /* live color from --color-accent which would be unreadable as a   */
            /* Tailwind arbitrary value.                                       */
            .hero-banner__icon {
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
