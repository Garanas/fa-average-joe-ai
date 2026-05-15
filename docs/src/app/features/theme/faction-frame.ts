import { ChangeDetectionStrategy, Component } from '@angular/core';

/**
 * Wraps content in a 9-slice frame made of eight separate texture pieces:
 *
 *   ┌──── horz_um repeats ────┐
 *   │ ul           ur │       Corners are 40 x 40, fixed.
 *   │  ┌──────────────┐  ur   Top/bottom edges tile horizontally (8 x 24 tile).
 *   │  │   <content>  │       Left/right edges tile vertically (24 x 8 tile).
 *   │  │              │       Sourced via `--frame-*` custom properties, which
 *   │  └──────────────┘       are set per-faction by ThemeService.
 *   │ ll           lr │
 *   └────  lm  ───────┘
 *
 * The frame is layout-only — pass content in via ng-content.
 */
@Component({
  selector: 'app-faction-frame',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="faction-frame">
      <div class="faction-frame__corner faction-frame__corner-ul"></div>
      <div class="faction-frame__edge faction-frame__edge-top"></div>
      <div class="faction-frame__corner faction-frame__corner-ur"></div>

      <div class="faction-frame__edge faction-frame__edge-left"></div>
      <div class="faction-frame__content"><ng-content /></div>
      <div class="faction-frame__edge faction-frame__edge-right"></div>

      <div class="faction-frame__corner faction-frame__corner-ll"></div>
      <div class="faction-frame__edge faction-frame__edge-bottom"></div>
      <div class="faction-frame__corner faction-frame__corner-lr"></div>
    </div>
  `,
  styles: [
    `
      :host {
        display: block;
      }

      .faction-frame {
        display: grid;
        grid-template-columns: 40px minmax(0, 1fr) 40px;
        grid-template-rows: 40px minmax(0, 1fr) 40px;
      }

      .faction-frame__corner,
      .faction-frame__edge {
        /* Sharp scaling when the browser zooms; default fallback for engines  */
        /* that don't recognize 'pixelated' (e.g. older Safari).               */
        image-rendering: pixelated;
        image-rendering: crisp-edges;
        background-repeat: no-repeat;
        pointer-events: none;
      }

      .faction-frame__corner {
        width: 40px;
        height: 40px;
        background-size: 40px 40px;
      }

      /* Corner offsets mirror the leftOffset/topOffset values in the     */
      /* engine's layout.lua: each corner translates outward by 1 px so   */
      /* its visible glow meets the adjacent edge flush, compensating     */
      /* for a 1-px transparent margin on the texture's outward sides.    */
      .faction-frame__corner-ul {
        background-image: var(--frame-ul, none);
        /* transform: translate(-1px, 0); */
      }
      .faction-frame__corner-ur {
        background-image: var(--frame-ur, none);
        /* transform: translate(1px, 0); */
      }
      .faction-frame__corner-ll {
        background-image: var(--frame-ll, none);
        /* transform: translate(-1px, 1px); */
      }
      .faction-frame__corner-lr {
        background-image: var(--frame-lr, none);
        /* transform: translate(1px, 1px); */
      }

      .faction-frame__edge-top,
      .faction-frame__edge-bottom {
        background-size: 8px 24px;
        background-repeat: repeat-x;

      }

      .faction-frame__edge-top {
        background-image: var(--frame-top, none);
        background-position: center top;
        transform: translate(0, 1px);
      }

      .faction-frame__edge-bottom {
        background-image: var(--frame-bottom, none);
        background-position: center bottom;
        transform: translate(0, -1px);
      }

      .faction-frame__edge-left,
      .faction-frame__edge-right {
        background-size: 24px 8px;
        background-repeat: repeat-y;
      }

      .faction-frame__edge-left {
        background-image: var(--frame-left, none);
        background-position: left center;
        transform: translate(2px, 0);
      }

      .faction-frame__edge-right {
        background-image: var(--frame-right, none);
        background-position: right center;
        transform: translate(-2px, 0);
      }

      .faction-frame__content {
        /* The corner pieces have a glow that extends inward; padding keeps  */
        /* text content from rendering under that glow.                      */
        padding: 0.5rem 1rem;
        min-width: 0;
        min-height: 0;
      }
    `,
  ],
})
export class FactionFrame {}
