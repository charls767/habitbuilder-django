# HBM-19 Accessibility Device Checklist

This checklist records the manual evidence required by `QUALITY-03`. Automated
widget tests complement this pass but do not replace TalkBack or VoiceOver.

## Build and environment

| Field | Value |
| --- | --- |
| Commit | |
| Tester | |
| Date | |
| Device or emulator | |
| OS version | |
| Assistive technology version | |
| Text scale | 100% / 200% |
| Contrast mode | Normal / High |

## Navigation method

Use swipe navigation first, then explore-by-touch. Complete every flow without
depending on visual position or color alone.

## Flow results

| Flow | TalkBack | VoiceOver | Notes or defect |
| --- | --- | --- | --- |
| Registration | PENDING | PENDING | |
| Login | PENDING | PENDING | |
| Daily completion logging | PENDING | PENDING | |
| Progress viewing | PENDING | PENDING | |

## Checks per flow

- Screen title is announced before interactive content.
- Inputs announce a unique label, value, validation state and password state.
- Buttons announce their action and disabled state.
- Selected status and period controls announce the selected value.
- Loading, save, error and synchronization messages are announced.
- Decorative icons are skipped.
- Focus order follows the visual and task order.
- All content remains reachable at 200% text scale.
- Text and controls remain distinguishable in high-contrast mode.

## Completion

Attach the completed table to HBM-19. Move the story to Listo only when all
eight platform/flow cells are PASS or have resolved Jira defects.
