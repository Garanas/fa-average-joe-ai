import {
    ChangeDetectionStrategy,
    Component,
    PLATFORM_ID,
    computed,
    inject,
    input,
} from '@angular/core';
import { DatePipe, DecimalPipe, isPlatformBrowser } from '@angular/common';
import { HttpErrorResponse, httpResource } from '@angular/common/http';
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

@Component({
    selector: 'app-release-embed',
    imports: [MarkdownComponent, DatePipe, DecimalPipe],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <aside class="overflow-hidden rounded-xl border border-border bg-surface">
            @if (data(); as data) {
                <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1 px-5 pt-4">
                    <span
                        class="font-display rounded-md bg-accent px-2 py-0.5 text-sm font-semibold text-[var(--mat-sys-on-primary)]"
                    >
                        {{ data.tag_name }}
                    </span>
                    <h3 class="font-display text-lg font-semibold tracking-tight">
                        {{ data.name || data.tag_name }}
                    </h3>
                    <time class="ml-auto text-xs text-muted" [attr.datetime]="data.published_at">
                        {{ data.published_at | date: 'longDate' }}
                    </time>
                </div>

                @if (data.body) {
                    <!--
                        Third-party content: the release body is authored on GitHub and may
                        contain raw HTML (markdown allows it). [disableSanitizer]="false" is
                        ngx-markdown's default, but it's set explicitly here as a trust-boundary
                        marker — if someone ever flips it, the diff makes the security
                        consequence visible. Sanitization runs through Angular's DomSanitizer
                        with SecurityContext.HTML, which strips <script>, <iframe>, inline
                        event handlers, and javascript: URLs.
                    -->
                    <div class="prose px-5 py-3">
                        <markdown [data]="data.body" [disableSanitizer]="false" />
                    </div>
                }

                @if (data.assets.length) {
                    <ul class="m-0 list-none border-t border-border bg-bg/40 px-5 py-3">
                        @for (asset of data.assets; track asset.browser_download_url) {
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
                        [href]="data.html_url"
                        target="_blank"
                        rel="noopener"
                    >
                        View on GitHub &rarr;
                    </a>
                </div>
            } @else if (release.isLoading()) {
                <div class="px-5 py-4 text-sm text-muted">Loading release&hellip;</div>
            } @else if (missing()) {
                <div class="px-5 py-4 text-sm text-muted">
                    No release published yet for
                    <code>{{ tag() }}</code> &mdash; the embed will appear automatically once it's
                    tagged.
                </div>
            } @else if (errorMessage(); as message) {
                <div class="px-5 py-4 text-sm text-muted">
                    Could not load release info: {{ message }}
                </div>
            } @else {
                <div class="px-5 py-4 text-sm text-muted">
                    Release embed will load in the browser.
                </div>
            }
        </aside>
    `,
    host: { class: 'block' },
})
export class ReleaseEmbed {
    readonly tag = input<string>('latest');

    private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));

    /* httpResource re-issues the request whenever `tag()` changes, and skips */
    /* it entirely during SSR by returning undefined from the request fn.    */
    protected readonly release = httpResource<GitHubRelease>(() => {
        if (!this.isBrowser) {
            return undefined;
        }
        const tag = this.tag();
        const url =
            tag === 'latest'
                ? `https://api.github.com/repos/${REPO}/releases/latest`
                : `https://api.github.com/repos/${REPO}/releases/tags/${encodeURIComponent(tag)}`;
        return { url, headers: { Accept: 'application/vnd.github+json' } };
    });

    /**
     * Safe accessor for the resolved value. `release.value()` throws a
     * ResourceValueError if accessed while the resource is in the error
     * state, so the template never reads it directly.
     */
    protected readonly data = computed(() =>
        this.release.hasValue() ? this.release.value() : undefined,
    );

    /** True only for the "release not tagged yet" case (HTTP 404). */
    protected readonly missing = computed(() => {
        const err = this.release.error();
        return err instanceof HttpErrorResponse && err.status === 404;
    });

    /** Human-readable error string for non-404 failures; undefined otherwise. */
    protected readonly errorMessage = computed(() => {
        const err = this.release.error();
        if (!err || (err instanceof HttpErrorResponse && err.status === 404)) {
            return undefined;
        }
        if (err instanceof HttpErrorResponse) {
            return `GitHub API returned ${err.status} ${err.statusText}`;
        }
        return err.message;
    });
}
