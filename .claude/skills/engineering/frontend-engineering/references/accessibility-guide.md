# Accessibility Guide Reference

> Load this file when implementing accessible interactive widgets. Covers ARIA roles, keyboard interactions, focus management, and testing.

## ARIA Roles Quick Reference

| Role | Use Case | Keyboard | Notes |
|------|----------|----------|-------|
| `button` | Clickable action | Enter, Space | Use `<button>`, not `<div role="button">` |
| `link` | Navigation | Enter | Use `<a href>`, not `<span role="link">` |
| `tab` | Tab in tablist | Arrow keys | Must be inside `role="tablist"` |
| `tabpanel` | Content for tab | — | `aria-labelledby` pointing to its tab |
| `dialog` | Modal/popup | Escape to close | Trap focus, `aria-modal="true"` |
| `alertdialog` | Confirmation dialog | Escape | Like dialog but announces immediately |
| `alert` | Status message | — | Announces immediately, no focus change |
| `status` | Live region update | — | Polite announcement (doesn't interrupt) |
| `menu` | Action menu | Arrow keys, Enter | NOT for navigation (use `nav` instead) |
| `menuitem` | Item in menu | Arrow keys | Inside `role="menu"` |
| `combobox` | Autocomplete input | Arrow, Enter, Esc | Complex — see pattern below |
| `listbox` | Selection list | Arrow keys | Single or multi-select |
| `option` | Item in listbox | — | Inside `role="listbox"` |
| `tree` | Hierarchical list | Arrow keys | Expand/collapse with Enter |
| `treeitem` | Item in tree | — | Inside `role="tree"` |
| `tooltip` | Descriptive popup | — | `aria-describedby` on trigger |
| `progressbar` | Loading/progress | — | `aria-valuenow`, `aria-valuemin`, `aria-valuemax` |
| `switch` | On/off toggle | Space | `aria-checked="true/false"` |

**Rule:** Use semantic HTML first. Only reach for ARIA roles when no native element exists for the pattern.

## Accessible Widget Patterns

### Modal / Dialog

```tsx
function Modal({ isOpen, onClose, title, children }: ModalProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocus.current = document.activeElement as HTMLElement;
      dialogRef.current?.showModal();
    } else {
      dialogRef.current?.close();
      previousFocus.current?.focus();  // Restore focus on close
    }
  }, [isOpen]);

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby="dialog-title"
      onClose={onClose}
      onKeyDown={(e) => { if (e.key === 'Escape') onClose(); }}
    >
      <h2 id="dialog-title">{title}</h2>
      <div>{children}</div>
      <button onClick={onClose}>Close</button>
    </dialog>
  );
}
```

**Requirements:**
- Focus trapped inside modal (Tab cycles within, not outside)
- Escape closes the modal
- Focus returns to trigger element on close
- Background content inert (`<dialog>` handles this natively, or use `inert` attribute)
- `aria-labelledby` pointing to modal heading

### Dropdown Menu

```tsx
function DropdownMenu({ trigger, items }: DropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const menuRef = useRef<HTMLUListElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);

  const handleKeyDown = (e: KeyboardEvent) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setActiveIndex(i => Math.min(i + 1, items.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setActiveIndex(i => Math.max(i - 1, 0));
        break;
      case 'Enter':
      case ' ':
        e.preventDefault();
        if (activeIndex >= 0) items[activeIndex].action();
        setIsOpen(false);
        buttonRef.current?.focus();
        break;
      case 'Escape':
        setIsOpen(false);
        buttonRef.current?.focus();
        break;
      case 'Home':
        e.preventDefault();
        setActiveIndex(0);
        break;
      case 'End':
        e.preventDefault();
        setActiveIndex(items.length - 1);
        break;
    }
  };

  return (
    <div>
      <button
        ref={buttonRef}
        aria-haspopup="true"
        aria-expanded={isOpen}
        onClick={() => { setIsOpen(!isOpen); setActiveIndex(0); }}
      >
        {trigger}
      </button>
      {isOpen && (
        <ul ref={menuRef} role="menu" onKeyDown={handleKeyDown}>
          {items.map((item, i) => (
            <li
              key={item.id}
              role="menuitem"
              tabIndex={i === activeIndex ? 0 : -1}
              aria-current={i === activeIndex}
              onClick={() => { item.action(); setIsOpen(false); }}
            >
              {item.label}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

**Requirements:**
- ArrowDown/Up navigates items
- Enter/Space activates item
- Escape closes and returns focus to trigger
- Home/End go to first/last item
- Type-ahead: typing characters jumps to matching item

### Tabs

```tsx
function Tabs({ tabs }: { tabs: TabConfig[] }) {
  const [activeTab, setActiveTab] = useState(tabs[0].id);

  const handleKeyDown = (e: KeyboardEvent, index: number) => {
    let newIndex = index;
    if (e.key === 'ArrowRight') newIndex = (index + 1) % tabs.length;
    else if (e.key === 'ArrowLeft') newIndex = (index - 1 + tabs.length) % tabs.length;
    else if (e.key === 'Home') newIndex = 0;
    else if (e.key === 'End') newIndex = tabs.length - 1;
    else return;

    e.preventDefault();
    setActiveTab(tabs[newIndex].id);
    document.getElementById(`tab-${tabs[newIndex].id}`)?.focus();
  };

  return (
    <div>
      <div role="tablist" aria-label="Content sections">
        {tabs.map((tab, i) => (
          <button
            key={tab.id}
            id={`tab-${tab.id}`}
            role="tab"
            aria-selected={activeTab === tab.id}
            aria-controls={`panel-${tab.id}`}
            tabIndex={activeTab === tab.id ? 0 : -1}
            onClick={() => setActiveTab(tab.id)}
            onKeyDown={(e) => handleKeyDown(e, i)}
          >
            {tab.label}
          </button>
        ))}
      </div>
      {tabs.map(tab => (
        <div
          key={tab.id}
          id={`panel-${tab.id}`}
          role="tabpanel"
          aria-labelledby={`tab-${tab.id}`}
          hidden={activeTab !== tab.id}
          tabIndex={0}
        >
          {tab.content}
        </div>
      ))}
    </div>
  );
}
```

**Requirements:**
- Arrow keys move between tabs (wrapping)
- Only active tab is in tab order (`tabIndex={0}`)
- Panel linked to tab via `aria-controls` / `aria-labelledby`
- Home/End go to first/last tab

### Accordion

```tsx
function Accordion({ items }: { items: AccordionItem[] }) {
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  const toggle = (id: string) => {
    setExpanded(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  return (
    <div>
      {items.map(item => (
        <div key={item.id}>
          <h3>
            <button
              aria-expanded={expanded.has(item.id)}
              aria-controls={`accordion-panel-${item.id}`}
              onClick={() => toggle(item.id)}
            >
              {item.title}
              <span aria-hidden="true">{expanded.has(item.id) ? '−' : '+'}</span>
            </button>
          </h3>
          <div
            id={`accordion-panel-${item.id}`}
            role="region"
            aria-labelledby={`accordion-header-${item.id}`}
            hidden={!expanded.has(item.id)}
          >
            {item.content}
          </div>
        </div>
      ))}
    </div>
  );
}
```

### Toast / Notification

```tsx
function ToastContainer({ toasts }: { toasts: Toast[] }) {
  return (
    <div aria-live="polite" aria-atomic="false" className="toast-container">
      {toasts.map(toast => (
        <div key={toast.id} role="status" className={`toast toast-${toast.type}`}>
          <p>{toast.message}</p>
          <button aria-label="Dismiss notification" onClick={() => dismiss(toast.id)}>
            <XIcon aria-hidden="true" />
          </button>
        </div>
      ))}
    </div>
  );
}
```

**Requirements:**
- Use `aria-live="polite"` for non-urgent, `"assertive"` for critical
- Toasts should auto-dismiss (5-10 seconds) with option to persist on hover
- Dismiss button must be keyboard accessible
- Don't stack more than 3 toasts — queue the rest

## Focus Management

### Focus Trap (for modals)

```tsx
function useFocusTrap(ref: RefObject<HTMLElement>, isActive: boolean) {
  useEffect(() => {
    if (!isActive || !ref.current) return;

    const focusableSelector = [
      'a[href]', 'button:not([disabled])', 'input:not([disabled])',
      'select:not([disabled])', 'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])'
    ].join(', ');

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;
      const focusable = ref.current!.querySelectorAll<HTMLElement>(focusableSelector);
      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [ref, isActive]);
}
```

### Focus Restoration

Always restore focus to the element that triggered a modal/overlay:

```tsx
function useRestoreFocus() {
  const triggerRef = useRef<HTMLElement | null>(null);

  const saveFocus = () => {
    triggerRef.current = document.activeElement as HTMLElement;
  };

  const restoreFocus = () => {
    triggerRef.current?.focus();
    triggerRef.current = null;
  };

  return { saveFocus, restoreFocus };
}
```

### Roving Tabindex

For lists, toolbars, tab lists where only one item is tabbable at a time:

```
Principle: Only the active/focused item has tabIndex={0}.
All other items have tabIndex={-1}.
Arrow keys move focus between items.
Tab exits the group entirely (to the next focusable element).
```

### Skip Links

```html
<!-- First element in body — hidden until focused -->
<a href="#main-content" class="skip-link">Skip to main content</a>

<style>
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  padding: 8px 16px;
  background: #000;
  color: #fff;
  z-index: 9999;
}
.skip-link:focus {
  top: 0;
}
</style>
```

## Keyboard Interaction Patterns

| Widget | Keys | Behavior |
|--------|------|----------|
| Button | Enter, Space | Activate |
| Link | Enter | Navigate |
| Checkbox | Space | Toggle |
| Radio group | Arrow keys | Move selection, wrapping |
| Tabs | Arrow keys | Switch tab, wrapping |
| Menu | Arrow keys, Enter, Esc | Navigate, select, close |
| Dialog | Escape | Close |
| Combobox | Arrow, Enter, Esc | Navigate options, select, close |
| Slider | Arrow keys, Home, End | Adjust value |
| Tree | Arrow keys, Enter | Navigate, expand/collapse |
| Listbox | Arrow keys, Space | Navigate, select |

**Universal:**
- Tab moves to next interactive element
- Shift+Tab moves to previous
- Escape closes overlays/popups
- Enter submits forms (from text inputs)

## Testing Accessibility

### Automated (catches ~30% of issues)

```bash
# axe-core integration
npm install @axe-core/react  # Development overlay
npm install axe-core          # Testing

# In tests
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

test('page has no accessibility violations', async () => {
  const { container } = render(<MyPage />);
  expect(await axe(container)).toHaveNoViolations();
});
```

### Manual Checklist (catches the other 70%)

```
KEYBOARD:
□ Tab through entire page — focus order is logical
□ All interactive elements reachable by keyboard
□ Focus indicator visible on every focused element
□ Can operate all widgets without mouse
□ Escape closes modals, dropdowns, popovers
□ No keyboard traps (can always Tab away)

SCREEN READER:
□ Headings create logical document outline
□ Images have appropriate alt text
□ Form inputs have labels (visible or aria-label)
□ Error messages are announced
□ Dynamic content changes are announced (live regions)
□ Decorative elements hidden (aria-hidden="true")

VISUAL:
□ Text meets contrast ratio (4.5:1 normal, 3:1 large)
□ Not relying on color alone to convey information
□ Page usable at 200% zoom
□ No information lost when animations disabled
□ Focus indicators meet 3:1 contrast against adjacent colors
```

### Screen Reader Testing Priority

| Screen Reader | Browser | OS | Priority |
|---------------|---------|-----|----------|
| VoiceOver | Safari | macOS/iOS | High |
| NVDA | Firefox | Windows | High |
| JAWS | Chrome | Windows | Medium |
| TalkBack | Chrome | Android | Medium |

**Minimum:** Test with VoiceOver + Safari (macOS) and NVDA + Firefox (Windows). These cover ~80% of screen reader users.
