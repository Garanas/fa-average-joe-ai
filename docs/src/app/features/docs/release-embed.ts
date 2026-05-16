import {
    ChangeDetectionStrategy,
    Component,
    PLATFORM_ID,
    computed,
    effect,
    inject,
    input,
    signal
} from '@angular/core';
import { DatePipe, DecimalPipe, isPlatformBrowser } from '@angular/common';
import { MarkdownComponent } from 'ngx-markdown';

const REPO = 'Garanas/fa-joe-ai';

interface GitHubReleaseAsset {
    name: string;
    size: number;
    browser_download_url: string;
}

interface GitHubRelease {
    name: string | null;
    tag_name: string;
    body: string | null;
    html_url: string;
    published_at: string;
    assets: GitHubReleaseAsset[];
}

type ReleaseState =
    | { status: 'idle' }
    | { status: 'loading' }
    | { status: 'ready'; data: GitHubRelease }
    | { status: 'missing' }
    | { status: 'error'; message: string };

@Component({
    selector: 'app-release-embed',
    imports: [MarkdownComponent, DatePipe, DecimalPipe],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <aside class="overflow-hidden rounded-xl border border-border bg-surface">
            @switch (state().status) {
                @case ('ready') {
                    @if (asReady(state()); as r) {
                        <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1 px-5 pt-4">
                            <span
                                class="font-display rounded-md bg-accent px-2 py-0.5 text-sm font-semibold"
                                style="color: var(--mat-sys-on-primary)"
                            >
                                {{ r.data.tag_name }}
                            </span>
                            <h3 class="font-display text-lg font-semibold tracking-tight">
                                {{ r.data.name || r.data.tag_name }}
                            </h3>
                            <time
                                class="ml-auto text-xs text-muted"
                                [attr.datetime]="r.data.published_at"
                            >
                                {{ r.data.published_at | date: 'longDate' }}
                            </time>
                        </div>

                        @if (r.data.body) {
                            <div class="prose px-5 py-3">
                                <markdown [data]="r.data.body" />
                            </div>
                        }

                        @if (r.data.assets.length) {
                            <ul class="m-0 list-none border-t border-border bg-bg/40 px-5 py-3">
                                @for (asset of r.data.assets; track asset.browser_download_url) {
                                    <li class="flex items-center justify-between gap-3 py-1 text-sm">
                                        <a
                                            class="truncate text-accent hover:underline"
                                            [href]="asset.browser_download_url"
                                            rel="noopener"
                                        >
                                            {{ asset.name }}
                                        </a>
                                        <span class="shrink-0 text-xs text-muted">
                                            {{ asset.size / 1024 | number: '1.0-0' }} KB
                                        </span>
                                    </li>
                                }
                            </ul>
                        }

                        <div class="border-t border-border px-5 py-2.5 text-right text-sm">
                            <a
                                class="text-accent hover:underline"
                                [href]="r.data.html_url"
                                target="_blank"
                                rel="noopener"
                            >
                                View on GitHub &rarr;
                            </a>
                        </div>
                    }
                }
                @case ('missing') {
                    <div class="px-5 py-4 text-sm text-muted">
                        No release published yet for
                        <code>{{ tag() }}</code> &mdash; the embed will appear automatically once it's tagged.
                    </div>
                }
                @case ('error') {
                    @if (asError(state()); as e) {
                        <div class="px-5 py-4 text-sm text-muted">
                            Could not load release info: {{ e.message }}
                        </div>
                    }
                }
                @case ('loading') {
                    <div class="px-5 py-4 text-sm text-muted">Loading release&hellip;</div>
                }
                @default {
                    <div class="px-5 py-4 text-sm text-muted">Release embed will load in the browser.</div>
                }
            }
        </aside>
    `,
    host: { class: 'block' }
})
export class ReleaseEmbed {
    readonly tag = input<string>('latest');

    private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));
    protected readonly state = signal<ReleaseState>({ status: 'idle' });

    constructor() {
        effect(() => {
            const tag = this.tag();
            if (!this.isBrowser) {
                return;
            }
            void this.fetchRelease(tag);
        });
    }

    protected asReady(s: ReleaseState): { status: 'ready'; data: GitHubRelease } | undefined {
        return s.status === 'ready' ? s : undefined;
    }

    protected asError(s: ReleaseState): { status: 'error'; message: string } | undefined {
        return s.status === 'error' ? s : undefined;
    }

    private async fetchRelease(tag: string): Promise<void> {
        this.state.set({ status: 'loading' });
        const url =
            tag === 'latest'
                ? `https://api.github.com/repos/${REPO}/releases/latest`
                : `https://api.github.com/repos/${REPO}/releases/tags/${encodeURIComponent(tag)}`;
        try {
            const response = await fetch(url, {
                headers: { Accept: 'application/vnd.github+json' }
            });
            if (response.status === 404) {
                this.state.set({ status: 'missing' });
                return;
            }
            if (!response.ok) {
                throw new Error(`GitHub API returned ${response.status} ${response.statusText}`);
            }
            const data = (await response.json()) as GitHubRelease;
            this.state.set({ status: 'ready', data });
        } catch (err) {
            this.state.set({
                status: 'error',
                message: err instanceof Error ? err.message : String(err)
            });
        }
    }
}
