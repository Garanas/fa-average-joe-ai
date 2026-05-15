import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { DatePipe, Location } from '@angular/common';
import { MarkdownComponent } from 'ngx-markdown';

import { DocEntry, docAssetPath, findDoc } from './content.manifest';
import { ReleaseEmbed } from './release-embed';

@Component({
    selector: 'app-doc-page',
    standalone: true,
    imports: [MarkdownComponent, RouterLink, DatePipe, ReleaseEmbed],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './doc-page.html',
    host: { class: 'block' }
})
export class DocPage {
    private readonly location = inject(Location);
    private readonly params = toSignal(inject(ActivatedRoute).paramMap, { requireSync: true });

    protected readonly entry = computed(() => {
        const params = this.params();
        const category = params.get('category');
        const slug = params.get('slug');
        if (!category || !slug) {
            return undefined;
        }
        return findDoc(category, slug);
    });

    protected readonly src = computed(() => {
        const entry = this.entry();
        return entry ? this.location.prepareExternalUrl(docAssetPath(entry)) : undefined;
    });

    protected releaseTag(entry: DocEntry): string {
        return entry.release?.tag ?? 'latest';
    }
}
