# Research — Reference Material

Supporting templates, research types, and section guidelines for the research skill.

---

## Research Document Template

Use this template for the final synthesized research document. All sections are required.

```markdown
# Research: <Topic Title>

**Date**: YYYY-MM-DD
**Type**: <Library Evaluation | Architecture Decision | Feature Investigation | Comparison>
**Status**: Complete
**Stack**: <detected stack summary>

---

## Summary

<3-5 sentence executive summary. State the topic, key findings, and the recommendation.
This section should be self-contained — a reader should understand the conclusion without
reading further.>

---

## Research Questions

### Q1: <question>
**Answer**: <concise answer, 2-4 sentences>

### Q2: <question>
**Answer**: <concise answer, 2-4 sentences>

### Q3: <question>
**Answer**: <concise answer, 2-4 sentences>

<...additional questions as needed>

---

## Findings

### <Theme 1: e.g., "API Surface and DX">

<Detailed findings organized by theme. Each finding should:>
- State the fact or observation
- Cite the source (documentation URL, GitHub issue, codebase file path)
- Note relevance to the project

### <Theme 2: e.g., "Performance Characteristics">

<...>

### <Theme 3: e.g., "Community and Maintenance">

<...>

---

## Compatibility Analysis

### Stack Compatibility

| Aspect | Status | Notes |
|--------|--------|-------|
| Framework version | Compatible / Incompatible / Untested | <details> |
| Build system | Compatible / Requires config | <details> |
| TypeScript | Full / Partial / None | <details> |
| Package manager | Works / Issues | <details> |
| Existing dependencies | No conflicts / Conflicts with X | <details> |

### Integration Complexity

- **Effort estimate**: <Low (hours) | Medium (1-2 days) | High (3+ days)>
- **Files affected**: <approximate count and key paths>
- **Breaking changes**: <Yes/No — details if yes>
- **Migration path**: <description of migration steps if replacing existing code>

---

## Recommendation

### Decision

<Clear, specific recommendation. Not "it depends" — make a call and justify it.>

### Rationale

<3-5 bullet points explaining why this is the right choice.>

### Comparison Matrix (if applicable)

| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| TypeScript support | Excellent | Good | Poor |
| Bundle size | 12KB | 45KB | 8KB |
| Community activity | High | Medium | Low |
| Learning curve | Low | Medium | High |
| Integration effort | Low | Medium | Low |
| **Overall** | **Recommended** | Acceptable | Not recommended |

---

## Implementation Sketch

<High-level implementation steps, adapted to the detected stack. Include:>

### Step 1: <title>
<Description of what to do. Include key code patterns.>

```<language>
// Example code adapted to project conventions
```

### Step 2: <title>
<...>

### Step 3: <title>
<...>

### Configuration Changes
<Any config file changes needed (package.json, framework config, env vars, etc.)>

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| <risk description> | Low/Medium/High | Low/Medium/High | <mitigation strategy> |
| <risk description> | Low/Medium/High | Low/Medium/High | <mitigation strategy> |

### Open Questions

- <Any questions that could not be answered with available information>
- <Areas that need further investigation or testing>

---

## References

1. <Title> — <URL> — <brief description of what it covers>
2. <Title> — <URL> — <brief description>
3. <Codebase file path> — <what it demonstrates about current implementation>
```

---

## Research Types

### Library Evaluation

**When to use**: User wants to evaluate a specific library or choose between libraries.

**Focus areas**:
- API surface and developer experience
- TypeScript support quality
- Bundle size and tree-shaking
- Version compatibility with project stack
- Maintenance health (last release, open issues, contributors)
- Migration path from current implementation (if any)

**Key questions to generate**:
- How does this integrate with the detected framework?
- What is the bundle size impact?
- Is it actively maintained?
- What do real users report as pain points?
- How does it compare to alternatives?

### Architecture Decision

**When to use**: User needs to decide on an architectural approach (state management strategy, API design, data flow pattern, etc.).

**Focus areas**:
- Trade-offs between approaches
- How the approach scales with project growth
- Impact on testing and maintainability
- Alignment with team experience and project conventions
- Precedent in similar projects

**Key questions to generate**:
- What are the concrete trade-offs?
- How does this affect testing?
- What does the migration path look like?
- How does this scale?
- What patterns does the existing codebase already follow?

### Feature Investigation

**When to use**: User needs to understand how to implement a specific feature (auth, payments, real-time sync, etc.).

**Focus areas**:
- Available approaches and services
- Integration requirements
- Security implications
- Cost and scaling considerations
- Existing code that can be reused

**Key questions to generate**:
- What are the available approaches?
- What are the security requirements?
- How does this affect the user experience?
- What infrastructure changes are needed?
- What is the cost model at scale?

### Comparison

**When to use**: User wants a head-to-head comparison of options (frameworks, services, patterns).

**Focus areas**:
- Feature parity matrix
- Performance benchmarks
- Developer experience comparison
- Community and ecosystem comparison
- Total cost of ownership

**Key questions to generate**:
- What criteria matter most for this project?
- How do options compare on each criterion?
- What are the deal-breakers?
- What is the switching cost if the choice proves wrong?
- Which option aligns best with the team's strengths?

---

## Implementation Sketch Guidelines

The Implementation Sketch section must be adapted to whatever stack was detected. Follow these guidelines:

### General Rules
- Reference actual project file paths (e.g., "add to your existing `src/composables/` directory")
- Use the project's detected package manager for install commands
- Follow the project's detected coding patterns (Composition API vs Options API, etc.)
- Show configuration changes for the detected build system
- Include type definitions if the project uses TypeScript

### Stack-Specific Adaptation

When the detected stack includes specific frameworks or tools, adapt code examples:

- **Package installation**: Use the detected package manager (`pnpm add`, `yarn add`, `npm install`)
- **Import paths**: Follow the project's path alias conventions (`@/`, `~/`, relative)
- **Component patterns**: Match the project's component style (SFC Composition API, Options API, etc.)
- **State management**: Use the detected state library (Pinia, Vuex, composables, Redux, Zustand, etc.)
- **Testing**: Show test examples using the detected test runner (Vitest, Jest, etc.)
- **Configuration**: Show config changes for the detected build system (Vite, Webpack, Nuxt config, etc.)

If no specific stack is detected, use generic Node.js/TypeScript patterns and note where the user should adapt to their setup.

---

## Agent Output Format

Each research agent must write findings using this structure:

```markdown
# <Agent Name> — Research Findings

## Topic: <research topic>
## Date: <ISO date>

---

### Finding 1: <title>
**Source**: <URL or file path>
**Relevance**: <High | Medium | Low>
<2-4 sentence description of the finding>

### Finding 2: <title>
<...>

---

## Summary
- **Findings count**: <N>
- **Key insight**: <one sentence>
- **Confidence level**: <High | Medium | Low>
- **Gaps**: <what could not be determined>
```
