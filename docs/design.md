# Design System — Scientific Application

> **Extracted from:** Finch Project CSS  
> **Purpose:** Design tokens and guidelines for building consistent, accessible scientific interfaces  
> **Background:** `#f4f3ee` (warm beige) — non-negotiable

---

## 🎨 Color Palette

### Core Colors

```css
--bg-main: #f4f3ee;        /* Main background - warm beige */
--bg-card: #ffffff;        /* Card/elevated surface */
--text-primary: #001d3d;   /* Primary text - deep navy */
--accent: #003566;         /* Secondary text, links - navy blue */
--primary: #ffc300;        /* Primary actions - vibrant yellow */
--primary-hover: #ffd60a;  /* Primary hover state - lighter yellow */
```

### Extended Palette (System Colors)

```css
/* Success State */
--success: #003566;        /* Reusing accent for success (consider adding dedicated green) */
--success-bg: rgba(0, 53, 102, 0.1);

/* Warning State */
--warning: #f77f00;        /* Orange for warnings */
--warning-bg: rgba(247, 127, 0, 0.1);

/* Error State */
--error: #d62828;          /* Red for errors */
--error-bg: rgba(214, 40, 40, 0.1);

/* Info State */
--info: #003566;           /* Navy blue for informational */
--info-bg: rgba(0, 53, 102, 0.1);
```

### Opacity Variations

```css
/* Borders */
--border-light: rgba(0, 53, 102, 0.08);
--border-default: rgba(0, 53, 102, 0.15);
--border-strong: rgba(0, 53, 102, 0.3);

/* Backgrounds */
--overlay: rgba(0, 29, 61, 0.5);
--hover-bg: rgba(255, 195, 0, 0.1);
--active-bg: rgba(255, 195, 0, 0.15);
```

---

## 📝 Typography

### Font Families

```css
--font-mono: 'IBM Plex Mono', 'Courier New', monospace;
--font-sans: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

**Import:**
```html
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600;700&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap');
```

### Type Scale

```css
/* Headings - Use Mono */
--text-xs: 0.75rem;      /* 12px */
--text-sm: 0.8rem;       /* 12.8px */
--text-base: 0.95rem;    /* 15.2px */
--text-md: 1.1rem;       /* 17.6px */
--text-lg: 1.25rem;      /* 20px */
--text-xl: 1.5rem;       /* 24px */
--text-2xl: 1.75rem;     /* 28px */
```

### Font Weights

```css
--weight-regular: 400;
--weight-medium: 500;
--weight-semibold: 600;
--weight-bold: 700;
```

### Line Heights

```css
--leading-tight: 1.25;
--leading-normal: 1.5;
--leading-relaxed: 1.75;
```

### Usage Guidelines

- **Headings (h1-h6):** IBM Plex Mono, weight 600, letter-spacing -0.01em
- **Body text:** IBM Plex Sans, weight 400
- **Labels/UI:** IBM Plex Sans, weight 500
- **Buttons:** IBM Plex Mono, weight 600
- **Code/Data:** IBM Plex Mono, weight 400

---

## 📏 Spacing System

### Base Scale (4px grid)

```css
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-3: 0.75rem;   /* 12px */
--space-4: 1rem;      /* 16px */
--space-5: 1.25rem;   /* 20px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
--space-10: 2.5rem;   /* 40px */
--space-12: 3rem;     /* 48px */
```

### Component Spacing

```css
/* Padding */
--padding-xs: 0.5rem 0.75rem;      /* Compact elements */
--padding-sm: 0.6rem 0.875rem;     /* Small buttons, inputs */
--padding-base: 0.6rem 1.25rem;    /* Default buttons */
--padding-md: 0.75rem 1rem;        /* Medium elements */
--padding-lg: 0.875rem 1.75rem;    /* Large buttons */
--padding-card: 1.25rem;           /* Card body */
--padding-card-header: 1rem 1.25rem;

/* Gaps */
--gap-xs: 0.5rem;
--gap-sm: 0.75rem;
--gap-base: 1rem;
--gap-lg: 1.5rem;
```

---

## 🔲 Border & Radius

### Border Radius

```css
--radius-sm: 4px;
--radius: 8px;
--radius-lg: 12px;
--radius-full: 9999px;
```

### Border Width

```css
--border-1: 1px;
--border-2: 2px;
--border-3: 3px;
```

---

## 💫 Shadows & Effects

### Shadows

```css
--shadow-sm: 0 1px 4px rgba(0, 29, 61, 0.05);
--shadow: 0 2px 8px rgba(0, 29, 61, 0.08);
--shadow-md: 0 4px 12px rgba(0, 29, 61, 0.1);
--shadow-hover: 0 4px 16px rgba(0, 29, 61, 0.12);
--shadow-lg: 0 8px 24px rgba(0, 29, 61, 0.15);

/* Colored Shadows (for buttons) */
--shadow-primary: 0 2px 4px rgba(255, 195, 0, 0.3);
--shadow-primary-hover: 0 4px 8px rgba(255, 195, 0, 0.4);
--shadow-accent: 0 2px 4px rgba(0, 53, 102, 0.3);
--shadow-accent-hover: 0 4px 8px rgba(0, 53, 102, 0.4);
```

### Focus Rings

```css
--focus-ring-primary: 0 0 0 3px rgba(255, 195, 0, 0.2);
--focus-ring-accent: 0 0 0 3px rgba(0, 53, 102, 0.2);
--focus-ring-error: 0 0 0 3px rgba(214, 40, 40, 0.2);
```

---

## ⚡ Transitions & Animations

### Transitions

```css
--transition-fast: all 0.15s ease;
--transition-base: all 0.2s ease;
--transition-slow: all 0.3s ease;

--transition-colors: color 0.2s ease, background-color 0.2s ease, border-color 0.2s ease;
--transition-transform: transform 0.2s ease;
--transition-shadow: box-shadow 0.2s ease;
```

### Transform Effects

```css
/* Hover Lifts */
--lift-sm: translateY(-1px);
--lift-base: translateY(-2px);
--lift-lg: translateY(-4px);

/* Slide Effects */
--slide-right: translateX(4px);
--slide-left: translateX(-4px);
```

---

## 🧩 Component Tokens

### Buttons

```css
/* Primary Button */
--btn-primary-bg: var(--primary);
--btn-primary-bg-hover: var(--primary-hover);
--btn-primary-text: var(--text-primary);
--btn-primary-shadow: var(--shadow-primary);
--btn-primary-shadow-hover: var(--shadow-primary-hover);

/* Secondary Button (Outline) */
--btn-secondary-bg: transparent;
--btn-secondary-border: var(--accent);
--btn-secondary-text: var(--accent);
--btn-secondary-bg-hover: var(--accent);
--btn-secondary-text-hover: #ffffff;

/* Success Button */
--btn-success-bg: var(--accent);
--btn-success-bg-hover: var(--text-primary);
--btn-success-text: var(--bg-card);

/* Sizes */
--btn-height-sm: 32px;
--btn-height-base: 38px;
--btn-height-lg: 44px;
```

### Cards

```css
--card-bg: var(--bg-card);
--card-border: var(--border-light);
--card-radius: var(--radius-lg);
--card-shadow: var(--shadow);
--card-shadow-hover: var(--shadow-hover);
--card-padding: var(--padding-card);
--card-header-border: var(--border-light);
```

### Forms

```css
/* Inputs */
--input-bg: var(--bg-card);
--input-border: var(--border-default);
--input-border-focus: var(--primary);
--input-text: var(--text-primary);
--input-radius: var(--radius);
--input-padding: 0.6rem 0.875rem;
--input-focus-ring: var(--focus-ring-primary);

/* Error State */
--input-border-error: var(--error);
--input-focus-ring-error: var(--focus-ring-error);

/* Disabled State */
--input-bg-disabled: rgba(0, 53, 102, 0.05);
--input-text-disabled: rgba(0, 29, 61, 0.4);
```

### Navbar

```css
--navbar-bg: var(--bg-card);
--navbar-border: var(--border-light);
--navbar-shadow: var(--shadow);
--navbar-padding: 0.75rem 1.5rem;
--navbar-link-hover-bg: var(--hover-bg);
--navbar-link-active-bg: var(--primary);
```

---

## 📐 Layout Grid

### Breakpoints

```css
--breakpoint-sm: 576px;
--breakpoint-md: 768px;
--breakpoint-lg: 992px;
--breakpoint-xl: 1200px;
--breakpoint-2xl: 1400px;
```

### Container Widths

```css
--container-sm: 540px;
--container-md: 720px;
--container-lg: 960px;
--container-xl: 1140px;
--container-2xl: 1320px;
```

---

## 🎯 Usage Guidelines

### Color Usage Rules

1. **Text Hierarchy:**
   - Primary text: `#001d3d` (headings, important content)
   - Secondary text: `#003566` (body text, descriptions)
   - Muted text: `rgba(0, 29, 61, 0.6)` (captions, metadata)

2. **Interactive Elements:**
   - Primary actions: `#ffc300` (CTAs, submit buttons)
   - Secondary actions: `#003566` outline (cancel, back)
   - Links: `#003566` → hover to `#ffc300`

3. **System States:**
   - Success: Use `#003566` or add green (`#2d6a4f`)
   - Warning: `#f77f00`
   - Error: `#d62828`
   - Info: `#003566`

### Accessibility Standards

- **Contrast Ratios (WCAG AA):**
  - Normal text: minimum 4.5:1
  - Large text (18px+): minimum 3:1
  - UI components: minimum 3:1

- **Current Palette Compliance:**
  - ✅ `#001d3d` on `#f4f3ee`: 18.5:1 (Excellent)
  - ✅ `#003566` on `#f4f3ee`: 13.2:1 (Excellent)
  - ❌ `#ffc300` on `#f4f3ee`: 1.9:1 (Poor - use for backgrounds only)
  - ✅ `#ffc300` on `#001d3d`: 9.7:1 (Excellent - good for dark mode)

### Typography Best Practices

- **Headings:** Always use IBM Plex Mono with weight 600
- **Body:** IBM Plex Sans with weight 400, line-height 1.5
- **Never use yellow text on light backgrounds** (contrast failure)
- **Code/Data:** Always monospace font
- **Button labels:** Monospace, weight 600, `var(--text-base)` (0.95rem)

### Spacing Consistency

- Use **8px grid** for major layout spacing
- Use **4px grid** for component-internal spacing
- Card padding: `1.25rem` (20px)
- Button padding: `0.6rem 1.25rem` (9.6px 20px)
- Input padding: `0.6rem 0.875rem` (9.6px 14px)

### Component States

Every interactive element should have:
1. **Default state**
2. **Hover state** (subtle background change or lift)
3. **Active/pressed state** (remove lift, slightly darker)
4. **Focus state** (visible focus ring, never remove)
5. **Disabled state** (reduced opacity, no pointer events)

---

## 🚫 Anti-Patterns (Don't Do This)

1. ❌ **Never use `!important`** unless absolutely necessary for override
2. ❌ **Don't use yellow (`#ffc300`) for text** on light backgrounds
3. ❌ **Don't mix font families** within the same component
4. ❌ **Don't use arbitrary spacing** (stick to 4px/8px grid)
5. ❌ **Don't remove focus indicators** for accessibility
6. ❌ **Don't use pure black** (`#000000`) - use `#001d3d` instead
7. ❌ **Don't create components without hover/focus states**

---

## 🔄 Migration from Old CSS

When building new components:

1. **Extract colors** from old CSS → Use tokens above
2. **Standardize spacing** → Replace arbitrary values with spacing scale
3. **Remove `!important`** → Use proper specificity
4. **Add missing states** → Error, warning, disabled
5. **Test contrast** → Ensure WCAG AA compliance
6. **Add focus rings** → Every interactive element needs visible focus

---

## 📦 Implementation Example

```css
/* Example: Modern Button Component */
.btn {
  font-family: var(--font-mono);
  font-weight: var(--weight-semibold);
  font-size: var(--text-base);
  padding: var(--padding-base);
  border-radius: var(--radius);
  border: none;
  cursor: pointer;
  transition: var(--transition-base);
}

.btn-primary {
  background-color: var(--primary);
  color: var(--text-primary);
  box-shadow: var(--shadow-primary);
}

.btn-primary:hover {
  background-color: var(--primary-hover);
  transform: var(--lift-sm);
  box-shadow: var(--shadow-primary-hover);
}

.btn-primary:focus {
  outline: none;
  box-shadow: var(--shadow-primary), var(--focus-ring-primary);
}

.btn-primary:active {
  transform: translateY(0);
}

.btn-primary:disabled {
  background-color: var(--input-bg-disabled);
  color: var(--input-text-disabled);
  cursor: not-allowed;
  box-shadow: none;
}
```

---

## 🎨 Dark Mode Preparation (Future)

If you decide to add dark mode later, prepare these alternate values:

```css
[data-theme="dark"] {
  --bg-main: #0a0e27;
  --bg-card: #151935;
  --text-primary: #f4f3ee;
  --accent: #5988ff;
  --primary: #ffc300;
  --border-light: rgba(255, 255, 255, 0.08);
  --border-default: rgba(255, 255, 255, 0.15);
}
```

---

## 📚 Resources

- **IBM Plex Fonts:** [Google Fonts](https://fonts.google.com/specimen/IBM+Plex+Sans)
- **Contrast Checker:** [WebAIM](https://webaim.org/resources/contrastchecker/)
- **WCAG Guidelines:** [W3C WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/)

---

**Version:** 1.0  
**Last Updated:** February 14, 2026  
**Maintained By:** Design System Team
