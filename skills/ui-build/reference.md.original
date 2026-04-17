# UI Build — Reference Material

## UX Design Principles

### Fitts's Law
The time to reach a target is a function of distance to and size of the target.
- **Application**: Make primary action buttons large and place them near the user's current focus. Avoid tiny click targets in corners. Minimum touch target: 44x44px (mobile), 32x32px (desktop).

### Hick's Law
Decision time increases logarithmically with the number of choices.
- **Application**: Limit choices per screen. Use progressive disclosure — show 5-7 options at a time, group related actions in menus. Avoid overwhelming forms; break into steps.

### Miller's Law
Working memory holds approximately 7 (plus or minus 2) items.
- **Application**: Chunk information into groups of 5-7. Use card layouts, sections, and visual grouping. Tables with 20+ columns need column selection or horizontal grouping.

### Jakob's Law
Users spend most of their time on other sites and expect your site to work like those.
- **Application**: Follow established UI patterns. Navigation goes top or left. Tables are sortable. Search is top-right. Don't innovate on basic interactions.

### Doherty Threshold
Productivity soars when system response is under 400ms.
- **Application**: Show skeleton/loading states instantly on navigation. Use optimistic updates for mutations. Prefetch data on hover for likely next actions.

### Aesthetic-Usability Effect
Users perceive aesthetically pleasing designs as more usable.
- **Application**: Consistent spacing, alignment, and typography matter. Use the design system's tokens faithfully. Small visual polish (rounded corners, subtle shadows, transitions) significantly impacts perceived quality.

### Von Restorff Effect
Items that stand out from their peers are more memorable.
- **Application**: Use color, size, or position to highlight primary actions and critical information. But use sparingly — if everything is highlighted, nothing is.

### Law of Proximity
Objects near each other are perceived as related.
- **Application**: Group related form fields. Add spacing between unrelated sections. Use cards or visual containers to define boundaries.

### Law of Common Region
Elements sharing a visual boundary are perceived as a group.
- **Application**: Use cards, panels, and bordered sections to group related content. Backgrounds (even subtle shade differences) create regions.

---

## Visual Validation Procedure (Playwright MCP)

### Prerequisites
- Dev server running and accessible
- Playwright MCP tools available (check via ToolSearch)

### Viewport Definitions
| Name    | Width  | Height | Device Class |
|---------|--------|--------|-------------|
| Mobile  | 375px  | 812px  | iPhone 13   |
| Tablet  | 768px  | 1024px | iPad        |
| Desktop | 1440px | 900px  | Laptop      |

### Validation Steps

1. **Navigate** to the target page/route
2. **Wait** for content to stabilize (no loading spinners, network idle)
3. **Resize** browser to each viewport
4. **Screenshot** at each viewport
5. **Inspect** each screenshot for:

#### Layout Checks
- [ ] No horizontal overflow (no horizontal scrollbar on mobile)
- [ ] No overlapping elements
- [ ] Content fills available width appropriately
- [ ] Consistent padding/margins
- [ ] Navigation is accessible (hamburger menu on mobile, full nav on desktop)

#### Typography Checks
- [ ] Text is readable at all viewports (minimum 14px body text on mobile)
- [ ] No text truncation that hides critical information
- [ ] Headings have clear hierarchy

#### Component Checks
- [ ] Tables switch to cards or horizontal scroll on mobile
- [ ] Buttons are reachable (not hidden behind overlapping elements)
- [ ] Forms stack vertically on mobile
- [ ] Dialogs/modals fit the viewport

#### Interaction Checks
- [ ] Click primary action — does it respond?
- [ ] Tab through interactive elements — focus visible?
- [ ] Open dropdowns/menus — do they stay within viewport?

---

## Accessibility Checklist (WCAG 2.1 AA)

### Perceivable
- [ ] **1.1.1 Non-text Content**: Images have `alt` attributes. Decorative images use `alt=""`
- [ ] **1.3.1 Info and Relationships**: Headings use proper `h1`-`h6` hierarchy. Lists use `ul`/`ol`. Tables use `th`
- [ ] **1.3.2 Meaningful Sequence**: DOM order matches visual order
- [ ] **1.4.1 Use of Color**: Information is not conveyed by color alone (add icons or text)
- [ ] **1.4.3 Contrast**: Text meets 4.5:1 ratio (3:1 for large text). Use framework theme colors that are pre-verified
- [ ] **1.4.4 Resize Text**: Text can scale to 200% without loss of content
- [ ] **1.4.10 Reflow**: Content reflows at 320px width without horizontal scroll
- [ ] **1.4.11 Non-text Contrast**: UI components and graphics meet 3:1 ratio

### Operable
- [ ] **2.1.1 Keyboard**: All interactive elements reachable via keyboard
- [ ] **2.1.2 No Keyboard Trap**: Focus can always move away from any element
- [ ] **2.4.1 Skip Navigation**: Skip-to-content link if applicable
- [ ] **2.4.3 Focus Order**: Tab order follows logical reading order
- [ ] **2.4.6 Headings and Labels**: Headings and labels are descriptive
- [ ] **2.4.7 Focus Visible**: Keyboard focus indicator is clearly visible
- [ ] **2.5.5 Target Size**: Interactive targets are at least 44x44 CSS pixels on touch

### Understandable
- [ ] **3.1.1 Language**: `lang` attribute on `<html>` element
- [ ] **3.2.1 On Focus**: No unexpected context change on focus
- [ ] **3.2.2 On Input**: No unexpected context change on input (use submit buttons)
- [ ] **3.3.1 Error Identification**: Errors are clearly identified and described in text
- [ ] **3.3.2 Labels or Instructions**: Form inputs have visible labels
- [ ] **3.3.3 Error Suggestion**: When an error is detected, suggest correction if known

### Robust
- [ ] **4.1.2 Name, Role, Value**: Custom components have appropriate ARIA roles and properties
- [ ] **4.1.3 Status Messages**: Status updates use `aria-live` regions

---

## Component Spec Template

```markdown
### Component: [PascalCaseName]

**File**: `src/components/[path]/[PascalCaseName].vue`
**Estimated lines**: [number — must be under 300]

#### Purpose
[One sentence describing what this component does]

#### Props
| Prop | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| ... | ... | ... | ... | ... |

#### Emits
| Event | Payload Type | Description |
|-------|-------------|-------------|
| ... | ... | ... |

#### Slots
| Slot | Props | Description |
|------|-------|-------------|
| default | — | [description] |
| ... | ... | ... |

#### States
| State | Condition | Display |
|-------|-----------|---------|
| Loading | `loading === true` | [skeleton description] |
| Empty | `!data?.length` | [empty state description] |
| Error | `error !== null` | [error display description] |
| Populated | `data?.length > 0` | [normal content description] |

#### Children
- [ChildComponent1] — used for [purpose]
- [ChildComponent2] — used for [purpose]

#### Responsive Behavior
| Viewport | Behavior |
|----------|----------|
| Mobile (< 640px) | [description] |
| Tablet (640-1024px) | [description] |
| Desktop (> 1024px) | [description] |
```

---

## Wireframe Template Format

Use ASCII wireframes with these conventions:

```
┌─────────────────────────────────────────────────┐
│ [LayoutWrapper]                                  │
│ ┌─────────────────────────────────────────────┐ │
│ │ PageHeader: "Page Title"         [+ Action] │ │
│ ├─────────────────────────────────────────────┤ │
│ │ FilterBar: [Search___] [Status▾] [Date▾]   │ │
│ ├─────────────────────────────────────────────┤ │
│ │ DataTable / CardGrid                        │ │
│ │ ┌──────┬──────────┬────────┬──────────────┐ │ │
│ │ │ Name │ Status   │ Date   │ Actions      │ │ │
│ │ ├──────┼──────────┼────────┼──────────────┤ │ │
│ │ │ ...  │ [Badge]  │ ...    │ [Edit][Del]  │ │ │
│ │ └──────┴──────────┴────────┴──────────────┘ │ │
│ │ Pagination: [< 1 2 3 ... 10 >]             │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘

RESPONSIVE:
  Mobile (< 640px): Table → stacked cards, filters collapse to drawer
  Tablet (640-1024px): Table with horizontal scroll, filters stay visible
  Desktop (> 1024px): Full table, all columns visible
```

### Wireframe Symbols
| Symbol | Meaning |
|--------|---------|
| `[Button]` | Clickable button |
| `[Input___]` | Text input field |
| `[Select▾]` | Dropdown select |
| `[x]` or `[ ]` | Checkbox |
| `(o)` or `( )` | Radio button |
| `[Badge]` | Status badge/chip |
| `[Icon]` | Icon element |
| `[< 1 2 3 >]` | Pagination control |
| `───` | Horizontal divider |
| `│` | Vertical divider |
| `...` | Repeated content |

### Wireframe Rules
1. Always show the outermost layout wrapper
2. Name every component — no anonymous boxes
3. Show at least one row of data content
4. Include responsive behavior notes below the wireframe
5. Mark primary action buttons distinctly (e.g., `[+ Create New]`)
