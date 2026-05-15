import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { DatePipe } from '@angular/common';

import { entriesForCategory, findCategory } from './content.manifest';

@Component({
    selector: 'app-category-overview',
    standalone: true,
    imports: [RouterLink, DatePipe],
    changeDetection: ChangeDetectionStrategy.OnPush,
    templateUrl: './category-overview.html',
    host: { class: 'block' }
})
export class CategoryOverview {
    private readonly params = toSignal(inject(ActivatedRoute).paramMap, { requireSync: true });

    protected readonly category = computed(() => {
        const id = this.params().get('category');
        return id ? findCategory(id) : undefined;
    });

    protected readonly entries = computed(() => {
        const id = this.params().get('category');
        return id ? entriesForCategory(id) : [];
    });
}
