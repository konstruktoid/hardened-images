<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
instructions/written_language_instructions.md
Upstream commit: f4696ac18174422ba873bac1630628d49123c7c0
Do not edit locally; re-vendor from upstream instead.
-->

# Written Language Instructions

## Objective

Produce text that is formal, professional, precise, and concise. Prioritize clarity, accuracy,
and readability over stylistic variation.

One skill builds on this document and is worth applying alongside it: the
`github-actions-security` skill (`.agents/skills/github-actions-security/SKILL.md`) applies these
rules to the prose it writes, namely workflow comments and pull request descriptions explaining
a deliberate exception.

## Tone

### Required

- Use a formal and professional tone.
- Maintain an objective and neutral style.
- Be respectful and factual.
- Express confidence only when supported by evidence or context.
- Adapt terminology to the intended audience while maintaining professionalism.

### Avoid

- Conversational language.
- Slang, idioms, or colloquial expressions.
- Humor, sarcasm, or rhetorical questions unless explicitly requested.
- Marketing language, exaggerated claims, or emotional persuasion.

## Style

### Use

- Complete, grammatically correct sentences.
- Standard punctuation.
- Active voice where appropriate.
- Clear and logical sentence structure.
- Consistent terminology throughout the document.

### Do Not Use

Em dashes, arrow symbols, and conversational filler are among the most common
markers of machine-generated text, so avoiding them keeps the output from reading as
generated.

- Em dashes (`—`). Use a colon, a comma, or a separate sentence instead.
- Arrow symbols (`→`) in prose. Write the relation out, for example "maps to" or
  "results in". This restriction applies to prose only: arrows remain acceptable in
  diagrams, mapping tables, code, and command output, where they carry meaning that
  prose would not convey as clearly.
- Decorative punctuation or symbols.
- Emojis.
- Excessive exclamation marks.
- Multiple punctuation marks (for example, `!!` or `???`).

## Conciseness

Every sentence must contribute meaningful information.

### Required

- Eliminate redundant words and phrases.
- State the main point directly.
- Prefer specific wording over verbose explanations.
- Keep sentences as short as possible without sacrificing clarity.
- Remove repeated information.

### Avoid

- Empty introductory phrases.
- Redundant transitions.
- Filler words that do not add meaning.
- Unnecessary qualifiers.

### Examples

| Avoid | Prefer |
|--------|--------|
| It is important to note that... | Omit the phrase and state the point directly. |
| It should be noted that... | Omit the phrase. |
| Basically... | Omit. |
| Simply... | Omit unless required for meaning. |
| Just... | Omit unless required for meaning. |
| In today's world... | Begin with the actual subject. |
| Needless to say... | Omit. |
| As mentioned previously... | Refer only when necessary. |
| Delve into / dive into... | Name the specific action: investigate, examine, review. |
| In conclusion... / In summary... | Omit the label and state the concluding point directly. |

## Word Choice

### Prefer

- Precise terminology.
- Concrete language.
- Domain-specific vocabulary where appropriate.
- Consistent naming conventions.

### Avoid

- Vague adjectives such as *very*, *really*, *quite*, and *somewhat* unless required.
- Clichés.
- Buzzwords without technical meaning.
- Ambiguous pronouns when the reference is unclear.
- Inflated, abstract verbs and adjectives common in generated text, such as *delve*, *leverage*,
  *utilize*, *harness*, *streamline*, *underscore*, *foster*, *robust*, *seamless*, *pivotal*,
  *cutting-edge*, and *multifaceted*. Use the plain, specific word the sentence needs instead
  (*use* rather than *utilize*, *rely on* rather than *leverage*).
- Filler nouns such as *landscape*, *realm*, *tapestry*, *synergy*, and *underpinnings*.
- Formulaic transitions repeated across consecutive paragraphs, such as opening successive
  paragraphs with *Moreover*, *Furthermore*, *Additionally*, or *Notably*. Vary transitions, or
  omit them when the logical connection is already clear from the content.

## Formatting

- Use descriptive headings.
- Use numbered lists for sequential procedures.
- Use bullet lists for unordered information.
- Keep paragraphs focused on a single topic.
- Use tables only when they improve readability.
- Maintain consistent capitalization, formatting, and terminology.

## Clarity

- State information directly.
- Avoid ambiguity.
- Explain technical concepts only when necessary for the intended audience.
- Define abbreviations on first use.
- Use examples only when they improve understanding.

## Consistency

- Use consistent terminology throughout the document.
- Use the same grammatical person and tense unless context requires otherwise.
- Follow the same formatting conventions throughout the document.
- Avoid switching between synonymous terms for the same concept.

## Quality Checklist

Before producing the final output, verify that:

- The tone is formal and professional.
- The language is objective and precise.
- No em dashes (`—`) are present.
- No arrow symbols (`→`) are present in prose. Arrows inside diagrams, mapping tables,
  code, or command output are acceptable.
- No conversational fillers remain.
- No inflated generated-text markers (*delve*, *leverage*, *utilize*, *underscore*, *robust*,
  *seamless*, and similar) or formulaic transitions (*Moreover*, *Furthermore*) repeated across
  paragraphs.
- Every sentence adds meaningful information.
- Redundant words and repeated ideas have been removed.
- Grammar and punctuation are correct.
- Terminology is consistent.
- The document is concise, clear, and easy to read.
