# Frontend Design Pro — Standardized Test Brief

## The Challenge

Build a **single-page SaaS landing page** for a fictional AI code review tool called "CodeLens AI".

## Requirements

### Content
- **Hero section**: Headline "Ship Better Code, Faster" with a tagline about AI-powered code review
- **3 feature cards** in a bento/grid layout: "Instant Reviews", "Security Scanning", "Team Insights"
- **Stats strip**: "50,000+ repos", "2M+ reviews", "99.9% uptime"
- **CTA section**: "Start free trial" button with supporting text
- **Footer**: Simple links + copyright

### Design Constraints
- Dark theme (NOT white background)
- Must NOT use Inter, Roboto, or Arial — choose an expressive font pairing
- Must NOT use generic purple gradient on white — choose a unique color palette
- Must include at least ONE animation (hero reveal, stagger, scroll, or hover effect)
- Self-contained single HTML file with inline CSS and JS (no external deps except Google Fonts)
- Mobile-responsive (at minimum: hero + cards stack vertically)

### Quality Evaluation Criteria
Score 1-5 on each:
1. **Typography**: Intentional font choice, hierarchy, spacing
2. **Color palette**: Cohesive, non-generic, dark theme execution
3. **Spatial composition**: Layout rhythm, breathing room, visual flow
4. **Motion/animation**: At least one premium animation effect
5. **Overall polish**: Does it feel like a real product page, not a template?

## Prompt Template

Use the following as the generation prompt (prepend skill context as needed):

---

You are a premium frontend designer. Generate a complete, self-contained HTML file for a SaaS landing page for "CodeLens AI" — an AI-powered code review tool.

Requirements:
- Dark theme, NOT white background
- Do NOT use Inter, Roboto, or Arial fonts — choose expressive, premium font pairings from Google Fonts
- Do NOT use generic purple gradients OR cyan/teal on dark (the new AI convergence trap) — create a truly unique color palette
- Hero section: "Ship Better Code, Faster" headline with cinematic reveal animation
- 3 feature cards in a bento grid: "Instant Reviews", "Security Scanning", "Team Insights"
- Stats strip: "50,000+ repos", "2M+ reviews", "99.9% uptime"
- CTA section with "Start free trial" button
- Simple footer
- At least one premium animation (stagger reveal, glassmorphism, gradient glow, parallax)
- Mobile responsive
- Self-contained: inline CSS + JS, only external dependency is Google Fonts
- Use CSS custom properties for all design tokens
- GPU-safe animations only (transform, opacity)

Output ONLY the complete HTML file, no explanations.
