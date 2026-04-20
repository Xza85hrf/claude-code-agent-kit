---
name: prompt-engineering
description: Craft effective prompts using proven techniques — chain-of-thought, few-shot, structured output, role-play.
argument-hint: "Optimize this system prompt to reduce hallucination and improve structured JSON output"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: meta
references: []
thinking-level: high
---

# Prompt Engineering

## Core Techniques

| Technique | When to Use | Example |
|-----------|-------------|---------|
| **Zero-shot** | Simple tasks, well-known formats | `Extract the email addresses from this text:` |
| **Few-shot** | Complex formats, nuanced tasks | Provide 2-3 input/output examples |
| **Chain-of-thought** | Math, logic, multi-step reasoning | `Let's think step by step.` |
| **Self-consistency** | Multiple valid answers exist | Generate 3 responses, pick most common |
| **Tree-of-thought** | Complex planning, exploring options | Generate 3 solution paths, evaluate each |
| **ReAct** | Tasks needing external info + reasoning | `Given the search results, answer the question` |
| **Role-play** | Specific expertise, tone, perspective | `You are a senior security architect.` |

### Few-shot Template

```
Task: Sentiment classify
Input: This product is amazing!
Output: positive

Input: Battery died after one day.
Output: negative

Input: {USER_INPUT}
Output:
```

### Chain-of-thought Example

```
Question: If a train travels 120km in 2 hours, what's its average speed?

Step 1: Identify what we're asked to find → average speed
Step 2: Recall formula → speed = distance / time
Step 3: Plug in values → 120km / 2 hours = 60 km/h
Step 4: Verify units → km/h is correct for speed

Answer: 60 km/h
```

---

## Structured Output Patterns

### JSON Mode (Preferred)

```
Output valid JSON only. No markdown, no explanation.

Schema:
{
  "name": "string",
  "items": ["string"],
  "confidence": "number 0-1"
}
```

### XML Tags

```
<analysis>
  <step>Identify the main argument</step>
  <step>Evaluate evidence quality</step>
</analysis>
<summary>
  One-paragraph summary here
</summary>
```

### Markdown Headers

```
## Decision: [APPROVE/REJECT]

### Reasoning
- Factor 1
- Factor 2

### Risk Level: [LOW/MEDIUM/HIGH]
```

### Schema-Constrained

```
Respond with an array of objects matching this TypeScript:

interface Extraction {
  entity: "PERSON" | "ORG" | "PRODUCT";
  value: string;
  confidence: number;
}
```

---

## Anti-Hallucination Techniques

### 1. Citation Requirement

```
For each factual claim, cite the source document using [Doc N] notation.
If no source supports a claim, state "No source found" instead of guessing.
```

### 2. Confidence Scoring

```
Rate your confidence for each answer: HIGH (90%+), MEDIUM (70-90%), LOW (<70%).
For LOW confidence items, explicitly state what additional info you need.
```

### 3. "I Don't Know" Permission

```
If uncertain about any part, say "I don't know" or "I'm not sure."
Do NOT fabricate information. Honest uncertainty is preferred over hallucination.
```

### 4. Grounding with Context

```
Only use information from the provided context. Do not use external knowledge.

Context:
[INSERT RELEVANT DOCUMENTS]

Question: [USER QUESTION]
```

### 5. Uncertainty Elicitation

```
Before answering, consider: "What would make me wrong?"
List 2-3 potential failure modes or assumptions.
```

---

## System Prompt Template

```
# ROLE
[One-sentence definition of who/what the AI is]

# CORE FUNCTION
[Primary task description]

# OUTPUT FORMAT
[Required format - JSON, markdown, XML, etc.]
[Schema if applicable]

# CONSTRAINTS
- [Hard rule 1]
- [Hard rule 2]
- [Hard rule 3]

# STYLE
- [Tone: concise/verbose/technical]
- [Example of desired output]

# ANTI-HALLUCINATION
- Cite sources when making factual claims
- State "I don't know" rather than guess
- Flag uncertainty explicitly

# EXAMPLE
[One good example of expected input→output]
```

### Real Example

```
# ROLE
You are a code review assistant that identifies security vulnerabilities.

# CORE FUNCTION
Analyze code snippets for security issues and return structured findings.

# OUTPUT FORMAT
JSON array of vulnerabilities:
[{"severity": "HIGH|MEDIUM|LOW", "type": "string", "location": "string", "fix": "string"}]

# CONSTRAINTS
- Only report actual issues, never false positives
- If code is not provided, ask for it
- Do not modify the user's code

# STYLE
- Concise, technical
- Use CWE identifiers when possible

# ANTI-HALLUCINATION
- Only flag issues visible in provided code
- Say "No issues found" when appropriate
```

---

## Prompt Debugging Checklist

| Symptom | Likely Cause | Fix |
|---------|---------------|-----|
| Ignores format | Format not prominent enough | Put format instructions first |
| Inconsistent tone | No style guidance | Add "Always/Never" style rules |
| Hallucinates facts | No grounding context | Add "Only use provided context" |
| Over-explains | Too much preamble | Put instructions before examples |
| Misses edge cases | No edge case handling | Add "If X, do Y" rules |
| Too verbose | Token limit pressure | Add "Keep responses under N words" |
| Ignores constraints | Constraints buried | Use ALL CAPS or markup |

### Quick Diagnostic Questions

1. **Is the format requirement at the top?** Move format rules before task description
2. **Are examples showing wrong behavior?** Check your few-shot examples
3. **Is the model role-playing wrong?** Strengthen role definition
4. **Are you mixing tasks?** Split into separate prompts
5. **Is context too long?** Summarize or truncate; put critical info at start

---

## Token Optimization

### Concise Instruction Patterns

| Wordy | Optimized |
|-------|-----------|
| "I would like you to please..." | "Do X" |
| "Could you potentially..." | "Generate X" |
| "It would be great if you could..." | "Extract X" |
| "In conclusion, to summarize..." | "Summary:" |
| "Now, the next thing is..." | [Remove entirely] |

### Remove Redundancy

```
BEFORE:
Please read the following text carefully and thoroughly, taking your time to understand
the content completely before you proceed to extract the key information from it.

AFTER:
Extract key information from:
```

### Token-Efficient Formatting

```
✓ Good:
Name: John
Role: Engineer

✗ Verbose:
The person's name is John and their role is Engineer.
```

### Priority Ordering

Most important instructions go FIRST (models weight early tokens more heavily):

1. Output format (most critical)
2. Constraints (hard rules)
3. Task description
4. Examples
5. Style/voice (can be brief)

---

## Quick Reference Commands

```
# Debug a prompt
"Analyze why this prompt produces [bad output]: [PASTE PROMPT]"

# Optimize for tokens
"Reduce this prompt to essential instructions only: [PASTE PROMPT]"
# Use TOML for structured inputs (~50% fewer tokens than JSON)
# See: cost-aware-llm-pipeline skill for details

# Add structured output
"Convert this to JSON with schema: [TASK DESCRIPTION]"

# Fix hallucination
"Add anti-hallucination constraints to: [PROMPT]"
```
