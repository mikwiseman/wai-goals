# Today design QA — 2026-07-22

**Target**

- Surface: Today on iOS 26.2, 393 x 852 points, seeded sample data.
- Goal: make the first screen an airy, immediately actionable list without repeated representations or progress summaries.
- Comparison artifact: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/09-before-after-light.png`.

**Hierarchy and density**

- Removed the full-width emotional hero, artwork carousel, date label, progress bar, progress summary, repeated section heading, and enclosing card.
- Each goal now appears once: one 44-point completion control, one title, one concise metadata line, and one detail disclosure.
- Six goals fit in the seeded first viewport. Pending goals remain first; completed goals move below them.
- Settings and Add remain the only persistent top-level controls.
- Intention approval remains available as a native leading swipe action instead of another visible button.

**Motion and emotion**

- Ordinary completion stays inline: spring check, native success feedback, brief tinted row highlight, and animated reorder.
- Full-screen Escher artwork is reserved for rare streak milestones and achievements, where the emotional reward is meaningful.
- All custom motion is gated by Reduce Motion.

**Accessibility**

- Completion controls retain a minimum 44 x 44 point hit target and goal-specific labels.
- Goal detail rows have separate navigation labels and hints.
- Titles and metadata can expand at accessibility Dynamic Type sizes.
- Semantic colors and native list separators were checked in light and dark appearance.

**Rendered evidence**

- Before, light: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/03-today-seeded-before-light.png`
- After, light: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/05-today-after-light.png`
- After, dark: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/06-today-after-dark.png`
- Maximum Dynamic Type: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/10-today-max-dynamic-type.png`
- Completion motion: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/07-completion-motion.mp4`
- Motion contact sheet: `/Users/mikwiseman/.gstack/projects/wai-goals/minimalism-audit-2026-07-22/08-completion-motion-contact-sheet.png`

**Verification**

- Xcode test suite: 54 passed, 0 failed.
- Debug simulator build and launch: passed.
- Light and dark rendered states: passed.
- Ordinary completion: stayed inline and reordered the row.
- Three-week milestone: opened the immersive celebration and returned to the list.
- Remaining gap: physical-device haptic feel was not evaluated in this pass.

Final result: passed.
