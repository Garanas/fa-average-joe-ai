import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { App } from './app';

describe('App', () => {
    beforeEach(async () => {
        await TestBed.configureTestingModule({
            imports: [App],
            providers: [provideRouter([])]
        }).compileComponents();
    });

    it('should create the app', () => {
        const fixture = TestBed.createComponent(App);
        expect(fixture.componentInstance).toBeTruthy();
    });

    it('renders the shell brand, outlet and footer', () => {
        const fixture = TestBed.createComponent(App);
        fixture.detectChanges();
        const compiled = fixture.nativeElement as HTMLElement;

        const brand = compiled.querySelector('[data-testid="brand"]');
        expect(brand?.textContent?.trim()).toBe('Average Joe AI');
        expect(compiled.querySelector('router-outlet')).not.toBeNull();
        expect(compiled.querySelector('app-footer')).not.toBeNull();
    });
});
