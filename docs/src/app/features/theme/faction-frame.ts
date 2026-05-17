import { ChangeDetectionStrategy, Component, input } from '@angular/core';

/**
 * Wraps content in a two-layer faction frame:
 *
 *   ┌══ outer frame, with header strip + title ══┐
 *   ║                                            ║
 *   ║   ┌── inner 9-slice + brackets ──┐         ║
 *   ║   │       <content>              │         ║
 *   ║   └──────────────────────────────┘         ║
 *   ╚════════════════════════════════════════════╝
 *
 * Outer layer (this commit):
 *   - 4 outer corners + 4 outer edges from `/minimap-outer-border/*`
 *   - A header strip at the top, between the upper-left and upper-right corners,
 *     hosting the optional `title()` input rendered as a small all-caps label.
 *   - Outer corners are NOT symmetric: top corners are 36 × 36, bottom corners
 *     are 16 × 12. Top/bottom edges tile horizontally; side edges tile vertically.
 *
 * Inner layer (unchanged):
 *   - 4 inner corners (40 × 40) + 4 inner edges (8 × 24 / 24 × 8 tiles).
 *   - Two optional 3-piece brackets clamped to the left and right edges.
 *   - Content fills the inner frame edge-to-edge with an octagonal clip-path so
 *     it can't poke past the inner bevel.
 *
 * All texture URLs come from CSS custom properties set per-faction by
 * `ThemeService` (`--frame-*`, `--bracket-*`, `--outer-frame-*`).
 */
@Component({
    selector: 'app-faction-frame',
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="faction-frame">
            @if (showOuter) {
                <!-- Outer 9-slice frame. Order matters only for paint, not flow — -->
                <!-- the corners overlap the edges, so they come last.              -->
                <div class="faction-frame__outer faction-frame__outer-edge-top"></div>
                <div class="faction-frame__outer faction-frame__outer-edge-bottom"></div>
                <div class="faction-frame__outer faction-frame__outer-edge-left"></div>
                <div class="faction-frame__outer faction-frame__outer-edge-right"></div>

                <div class="faction-frame__outer faction-frame__outer-corner-ul"></div>
                <div class="faction-frame__outer faction-frame__outer-corner-ur"></div>
                <div class="faction-frame__outer faction-frame__outer-corner-ll"></div>
                <div class="faction-frame__outer faction-frame__outer-corner-lr"></div>

                <!-- Title slot, overlaid on the outer header strip between ul/ur. -->
                @if (title(); as titleText) {
                    <header class="faction-frame__title-bar">
                        <span class="faction-frame__title">{{ titleText }}</span>
                    </header>
                }
            }

            <!-- Inner 9-slice + clipped content. The body wrapper always       -->
            <!-- renders — only the *border* pieces gate on 'showInner'.        -->
            <div class="faction-frame__inner">
                <div class="faction-frame__content"><ng-content /></div>

                @if (showInner) {
                    <div class="faction-frame__edge faction-frame__edge-top"></div>
                    <div class="faction-frame__edge faction-frame__edge-bottom"></div>
                    <div class="faction-frame__edge faction-frame__edge-left"></div>
                    <div class="faction-frame__edge faction-frame__edge-right"></div>

                    <div class="faction-frame__corner faction-frame__corner-ul"></div>
                    <div class="faction-frame__corner faction-frame__corner-ur"></div>
                    <div class="faction-frame__corner faction-frame__corner-ll"></div>
                    <div class="faction-frame__corner faction-frame__corner-lr"></div>
                }
            </div>

            <!-- Brackets attach to the *outer* wrapper so their offsets are     -->
            <!-- measured against the outer frame, not the inner body. Kept at   -->
            <!-- this layer (after __inner) so they paint on top of inner +      -->
            <!-- content but underneath nothing important.                       -->
            @if (showBrackets) {
                <div class="faction-frame__bracket faction-frame__bracket-left">
                    <div class="faction-frame__bracket-t"></div>
                    <div class="faction-frame__bracket-m"></div>
                    <div class="faction-frame__bracket-b"></div>
                </div>
                <div class="faction-frame__bracket faction-frame__bracket-right">
                    <div class="faction-frame__bracket-t"></div>
                    <div class="faction-frame__bracket-m"></div>
                    <div class="faction-frame__bracket-b"></div>
                </div>
            }
        </div>
    `,
    styles: [
        `
            :host {
                display: block;
            }

            /* ===== Outer layer ============================================= */

            .faction-frame {
                position: relative;
                /* Outer-border thicknesses from the source PNGs:                */
                /*   top    36 px (corner ul/ur are 36 × 36, header strip lives  */
                /*          inside this band)                                    */
                /*   sides  16 px (vert_l / vert_r are 16 × 12)                  */
                /*   bottom 12 px (lm is 12 × 12, ll / lr are 16 × 12)           */
                padding: 36px 16px 12px 16px;
            }

            .faction-frame__outer {
                position: absolute;
                pointer-events: none;
                image-rendering: pixelated;
                image-rendering: crisp-edges;
                background-repeat: no-repeat;
            }

            /* Top corners are 36 × 36 (they include the header overhang). */
            .faction-frame__outer-corner-ul,
            .faction-frame__outer-corner-ur {
                width: 36px;
                height: 36px;
                background-size: 36px 36px;
            }
            .faction-frame__outer-corner-ul {
                top: 0;
                left: 0;
                background-image: var(--outer-frame-ul, none);
                /* TODO(translate): nudge to align with the inner frame's ul corner. */
            }
            .faction-frame__outer-corner-ur {
                top: 0;
                right: 0;
                background-image: var(--outer-frame-ur, none);
                /* TODO(translate): mirror of ul above. */
            }

            /* Bottom corners are 16 × 12 (no header on the bottom). */
            .faction-frame__outer-corner-ll,
            .faction-frame__outer-corner-lr {
                width: 16px;
                height: 12px;
                background-size: 16px 12px;
            }
            .faction-frame__outer-corner-ll {
                bottom: 0;
                left: 0;
                background-image: var(--outer-frame-ll, none);
                /* TODO(translate): nudge to align with the inner frame's ll corner. */
            }
            .faction-frame__outer-corner-lr {
                bottom: 0;
                right: 0;
                background-image: var(--outer-frame-lr, none);
                /* TODO(translate): mirror of ll above. */
            }

            /* Top edge: 12 × 36 tile, tiled horizontally between ul (36) and ur (36). */
            .faction-frame__outer-edge-top {
                top: 0;
                left: 36px;
                right: 36px;
                height: 36px;
                background-image: var(--outer-frame-top, none);
                background-size: 12px 36px;
                background-repeat: repeat-x;
                /* TODO(translate): seam-match against ul/ur if a 1-px gap shows. */
            }

            /* Bottom edge: 12 × 12 tile, tiled horizontally between ll (16) and lr (16). */
            .faction-frame__outer-edge-bottom {
                bottom: 0;
                left: 16px;
                right: 16px;
                height: 12px;
                background-image: var(--outer-frame-bottom, none);
                background-size: 12px 12px;
                background-repeat: repeat-x;
                /* TODO(translate): seam-match against ll/lr if a 1-px gap shows. */
            }

            /* Side edges: 16 × 12 tile, tiled vertically. Note the start/end  */
            /* offsets — sides span from below the top corners (36) down to    */
            /* above the bottom corners (12).                                  */
            .faction-frame__outer-edge-left,
            .faction-frame__outer-edge-right {
                top: 36px;
                bottom: 12px;
                width: 16px;
                background-size: 16px 12px;
                background-repeat: repeat-y;
            }
            .faction-frame__outer-edge-left {
                left: 0;
                background-image: var(--outer-frame-left, none);
                /* TODO(translate): if the left rail looks shifted vs ul, nudge here. */
            }
            .faction-frame__outer-edge-right {
                right: 0;
                background-image: var(--outer-frame-right, none);
                /* TODO(translate): mirror of left above. */
            }

            /* Header strip: overlays the top of the outer frame, between the  */
            /* upper-left and upper-right corners. The horz_um tile already    */
            /* carries the strip texture, so the title just sits on top.       */
            .faction-frame__title-bar {
                position: absolute;
                top: -4px;
                left: 36px;
                right: 36px;
                height: 36px;
                pointer-events: none;
                display: flex;
                align-items: center;
                justify-content: center;
                /* TODO(translate): vertically center the text inside the header  */
                /* strip — the strip occupies the upper portion of this 36 px box. */
            }

            .faction-frame__title {
                color: var(--color-text);
                font-family: var(--font-display);
                font-size: 0.6875rem;
                font-weight: 600;
                letter-spacing: 0.12em;
                text-transform: uppercase;
                white-space: nowrap;
                /* TODO(translate): adjust padding-top to seat the label inside    */
                /* the visible strip area (the lower ~10 px of horz_um is the      */
                /* edge texture, not the strip).                                    */
                padding-top: 2px;
            }

            /* ===== Inner layer (unchanged behaviour, just nested) =========== */

            .faction-frame__inner {
                position: relative;
                padding: 4px;
                /* Bevel size for the content's clipped corners. Should roughly match  */
                /* the inner bevel of the frame's corner texture (40 px corner minus   */
                /* 24 px edge thickness ≈ 16 px). Tune freely.                         */
                --corner-bevel: 6px;
                /* Inset for the polygon's four straight sides. The frame's edge       */
                /* textures have a soft inner glow that the raw content would render   */
                /* on top of — push the clipped content inward so the glow stays       */
                /* visible. Bumped corner-bevel above for the same reason on diagonals. */
                --content-inset: 4px;

                /* ----- Inner-frame tuning ----- */
                /* Shift the whole inner frame (wrapper + content + border anchors)    */
                /* via margin so corners, edges and the content's clipped bevel all    */
                /* move together. Positive values push the frame inward (frame         */
                /* shrinks); negative values push it outward (margins overflow into    */
                /* the outer padding band). Top and bottom are split because the       */
                /* outer chrome is asymmetric (36 px top vs 12 px bottom), so visual   */
                /* centering of the inner frame typically needs an asymmetric inset.   */
                --frame-inset-x: -12px;
                --frame-inset-top: -18px;
                --frame-inset-bottom: -12px;
                margin: var(--frame-inset-top) var(--frame-inset-x) var(--frame-inset-bottom);
            }

            /* Content fills the frame, but its corners are clipped to an octagon  */
            /* so it can't show in the frame's chamfered corner area. The eight    */
            /* border pieces below render on top of the content (absolute children */
            /* paint after non-positioned siblings in source order).               */
            .faction-frame__content {
                clip-path: polygon(
                    var(--corner-bevel) var(--content-inset),
                    calc(100% - var(--corner-bevel)) var(--content-inset),
                    calc(100% - var(--content-inset)) var(--corner-bevel),
                    calc(100% - var(--content-inset)) calc(100% - var(--corner-bevel)),
                    calc(100% - var(--corner-bevel)) calc(100% - var(--content-inset)),
                    var(--corner-bevel) calc(100% - var(--content-inset)),
                    var(--content-inset) calc(100% - var(--corner-bevel)),
                    var(--content-inset) var(--corner-bevel)
                );
                overflow: hidden;
                min-width: 0;
                min-height: 0;
            }

            .faction-frame__corner,
            .faction-frame__edge {
                position: absolute;
                pointer-events: none;
                /* Sharp scaling when the browser zooms; default fallback for engines  */
                /* that don't recognize 'pixelated' (e.g. older Safari).               */
                image-rendering: pixelated;
                image-rendering: crisp-edges;
                background-repeat: no-repeat;
            }

            .faction-frame__corner {
                width: 40px;
                height: 40px;
                background-size: 40px 40px;
            }

            .faction-frame__corner-ul {
                top: 0;
                left: 0;
                background-image: var(--frame-ul, none);
            }
            .faction-frame__corner-ur {
                top: 0;
                right: 0;
                background-image: var(--frame-ur, none);
            }
            .faction-frame__corner-ll {
                bottom: 0;
                left: 0;
                background-image: var(--frame-ll, none);
            }
            .faction-frame__corner-lr {
                bottom: 0;
                right: 0;
                background-image: var(--frame-lr, none);
            }

            .faction-frame__edge-top,
            .faction-frame__edge-bottom {
                left: 40px;
                right: 40px;
                height: 40px;
                background-size: 8px 24px;
                background-repeat: repeat-x;
            }

            .faction-frame__edge-top {
                top: 0;
                background-image: var(--frame-top, none);
                background-position: center top;
                transform: translate(0, 1px);
            }

            .faction-frame__edge-bottom {
                bottom: 0;
                background-image: var(--frame-bottom, none);
                background-position: center bottom;
                transform: translate(0, -1px);
            }

            .faction-frame__edge-left,
            .faction-frame__edge-right {
                top: 40px;
                bottom: 40px;
                width: 40px;
                background-size: 24px 8px;
                background-repeat: repeat-y;
            }

            .faction-frame__edge-left {
                left: 0;
                background-image: var(--frame-left, none);
                background-position: left center;
                transform: translate(2px, 0);
            }

            .faction-frame__edge-right {
                right: 0;
                background-image: var(--frame-right, none);
                background-position: right center;
                transform: translate(-2px, 0);
            }

            /* ----- Brackets -------------------------------------------------- */
            /* Each bracket is a vertical flex column with top + middle (repeat) */
            /* + bottom pieces sharing a spine. Spine aligns to the outer side   */
            /* of the bracket, arms reach inward toward the frame.               */
            /*                                                                   */
            /* Anchored to the outer .faction-frame wrapper, so top / bottom /  */
            /* left / right are measured against the outer dimensions (not the  */
            /* inner body).                                                     */

            .faction-frame__bracket {
                position: absolute;
                top: 0; /* TODO(translate): bump to 36px to clear the outer header strip. */
                bottom: 0; /* TODO(translate): bump to 12px to clear the outer bottom edge. */
                display: flex;
                flex-direction: column;
                pointer-events: none;

                /* ----- Bracket tuning ----- */
                /* All non-zero magic numbers in the bracket transforms below derive   */
                /* from these three variables. Right-bracket transforms mirror by      */
                /* multiplying with -1. The middle's margin matches --bracket-end-     */
                /* overlap so the spine stays continuous when top/bottom translate.    */
                --bracket-offset-x: 1px; /* base inward shift on every bracket piece */
                --bracket-mid-x-extra: 7px; /* extra inward shift for the narrower middle */
                --bracket-end-overlap: 8px; /* outward Y translate on top/bottom */
            }

            .faction-frame__bracket > div {
                image-rendering: pixelated;
                image-rendering: crisp-edges;
                flex-shrink: 0;
                /* No background-repeat here — it would beat .bracket-m's repeat-y on  */
                /* specificity. Top/bottom pieces match their box size exactly so the  */
                /* default 'repeat' renders one tile, equivalent to 'no-repeat'.       */
            }

            .faction-frame__bracket-t {
                width: 32px;
                height: 72px;
                background-size: 32px 72px;
            }

            .faction-frame__bracket-m {
                width: 16px;
                flex: 1;
                background-size: 16px 4px;
                background-repeat: repeat-y;
                /* Compensate for the top/bottom pieces' outward Y translates so the */
                /* spine stays continuous.                                           */
                margin-top: calc(-1 * var(--bracket-end-overlap));
                margin-bottom: calc(-1 * var(--bracket-end-overlap));
            }

            .faction-frame__bracket-b {
                width: 24px;
                height: 32px;
                background-size: 32px 32px;
            }

            /* Left bracket: spine on left, arms reaching right into the frame.  */
            /* Anchored 16 px outside the frame so the widest piece (top, 32 px) */
            /* overlaps the frame's edge by 16 px.                               */
            .faction-frame__bracket-left {
                left: -16px;
                align-items: flex-start;
            }

            .faction-frame__bracket-left .faction-frame__bracket-t {
                background-image: var(--bracket-left-t, none);
                transform: translate(
                    var(--bracket-offset-x),
                    calc(-1 * var(--bracket-end-overlap))
                );
            }
            .faction-frame__bracket-left .faction-frame__bracket-m {
                background-image: var(--bracket-left-m, none);
                transform: translate(calc(var(--bracket-offset-x) + var(--bracket-mid-x-extra)), 0);
            }
            .faction-frame__bracket-left .faction-frame__bracket-b {
                background-image: var(--bracket-left-b, none);
                transform: translate(var(--bracket-offset-x), var(--bracket-end-overlap));
            }

            .faction-frame__bracket-right {
                right: -16px;
                align-items: flex-end;
            }

            .faction-frame__bracket-right .faction-frame__bracket-t {
                background-image: var(--bracket-right-t, none);
                transform: translate(
                    calc(-1 * var(--bracket-offset-x)),
                    calc(-1 * var(--bracket-end-overlap))
                );
            }
            .faction-frame__bracket-right .faction-frame__bracket-m {
                background-image: var(--bracket-right-m, none);
                transform: translate(
                    calc(-1 * (var(--bracket-offset-x) + var(--bracket-mid-x-extra))),
                    0
                );
            }
            .faction-frame__bracket-right .faction-frame__bracket-b {
                background-image: var(--bracket-right-b, none);
                /* X is not a clean mirror of the left side — the right-bottom atlas    */
                /* has its content shifted 2 px vs the left, so this needs an extra     */
                /* inward shift beyond the symmetric pattern. Promote 8px to its own    */
                /* variable if you want one knob; for now it's a literal acknowledging  */
                /* the asymmetry.                                                       */
                transform: translate(
                    calc(-1 * var(--bracket-offset-x) - 8px),
                    var(--bracket-end-overlap)
                );
            }
        `,
    ],
})
export class FactionFrame {
    /** Optional header label shown centered in the outer frame's top strip. */
    readonly title = input<string | undefined>(undefined);

    /* Debug-time layer toggles. Flip to `false` while tuning translations to  */
    /* isolate one layer — e.g. set `showOuter = false` to align the inner     */
    /* frame against the content without the outer chrome on top. The outer-  */
    /* padding on `.faction-frame` stays put even when `showOuter = false`,    */
    /* so the inner pieces don't shift in or out as you flip these. Always     */
    /* commit these as `true`.                                                 */
    protected readonly showOuter = true;
    protected readonly showInner = true;
    protected readonly showBrackets = false;
}
