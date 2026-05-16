import { ChangeDetectionStrategy, Component } from '@angular/core';

/**
 * Wraps content in a 9-slice frame made of eight separate texture pieces,
 * plus two optional 3-piece brackets clamped to the left and right edges.
 *
 *   ┌──── horz_um repeats ────┐
 *   │ ul           ur │       Corners are 40 x 40, fixed.
 *   │  ┌──────────────┐  ur   Top/bottom edges tile horizontally (8 x 24 tile).
 *   │  │   <content>  │       Left/right edges tile vertically (24 x 8 tile).
 *   │  │              │       Brackets: top (32x72) + mid (16x4 repeats) + bottom (24x32).
 *   │  └──────────────┘       All sourced via `--frame-*` / `--bracket-*` custom
 *   │ ll           lr │       properties set per-faction by ThemeService.
 *   └────  lm  ───────┘
 *
 * Layout model: content fills the frame edge-to-edge and gets a clip-path
 * with chamfered (octagonal) corners so it can't poke past the frame's
 * inner bevel. The eight border pieces and the two brackets are absolutely
 * positioned on top of the content, with `pointer-events: none` so they
 * never steal clicks.
 */
@Component({
    selector: 'app-faction-frame',
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="faction-frame">
            <div class="faction-frame__content"><ng-content /></div>

            <div class="faction-frame__edge faction-frame__edge-top"></div>
            <div class="faction-frame__edge faction-frame__edge-bottom"></div>
            <div class="faction-frame__edge faction-frame__edge-left"></div>
            <div class="faction-frame__edge faction-frame__edge-right"></div>

            <div class="faction-frame__corner faction-frame__corner-ul"></div>
            <div class="faction-frame__corner faction-frame__corner-ur"></div>
            <div class="faction-frame__corner faction-frame__corner-ll"></div>
            <div class="faction-frame__corner faction-frame__corner-lr"></div>

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
        </div>
    `,
    styles: [
        `
            :host {
                display: block;
            }

            .faction-frame {
                position: relative;
                padding: 4px;
                /* Bevel size for the content's clipped corners. Should roughly match  */
                /* the inner bevel of the frame's corner texture (40 px corner minus   */
                /* 24 px edge thickness ≈ 16 px). Tune freely.                         */
                --corner-bevel: 16px;

                /* ----- Bracket tuning ----- */
                /* All non-zero magic numbers in the bracket transforms below derive   */
                /* from these three variables. Right-bracket transforms mirror by      */
                /* multiplying with -1. The middle's margin matches --bracket-end-     */
                /* overlap so the spine stays continuous when top/bottom translate.    */
                --bracket-offset-x: 5px; /* base inward shift on every bracket piece */
                --bracket-mid-x-extra: 7px; /* extra inward shift for the narrower middle */
                --bracket-end-overlap: 4px; /* outward Y translate on top/bottom */
            }

            /* Content fills the frame, but its corners are clipped to an octagon  */
            /* so it can't show in the frame's chamfered corner area. The eight    */
            /* border pieces below render on top of the content (absolute children */
            /* paint after non-positioned siblings in source order).               */
            .faction-frame__content {
                clip-path: polygon(
                    var(--corner-bevel) 0,
                    calc(100% - var(--corner-bevel)) 0,
                    100% var(--corner-bevel),
                    100% calc(100% - var(--corner-bevel)),
                    calc(100% - var(--corner-bevel)) 100%,
                    var(--corner-bevel) 100%,
                    0 calc(100% - var(--corner-bevel)),
                    0 var(--corner-bevel)
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

            .faction-frame__bracket {
                position: absolute;
                top: 0;
                bottom: 0;
                display: flex;
                flex-direction: column;
                pointer-events: none;
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
export class FactionFrame {}
