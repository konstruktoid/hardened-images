<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
instructions/written_language_instructions.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Written Language Instructions

## Objective

Produce text that is formal, professional, precise, and concise. Prioritize clarity, accuracy,
and readability over stylistic variation.

Four skills build on this document and are worth applying alongside it. All of them write prose
into a repository rather than reporting only to a reader:

- `.agents/skills/github-actions-security/SKILL.md` applies these rules to workflow comments and to
  pull request descriptions explaining a deliberate exception.
- `.agents/skills/ansible-verification-loop/SKILL.md` applies them to the documentation a variable
  change requires: role README entries and `meta/argument_specs.yml` descriptions.
- `.agents/skills/github-repository-security/SKILL.md` applies them to `SECURITY.md`, a ruleset
  description, and the statement of what a repository's agent-facing content reads and sends.
- `.agents/skills/github-organization-governance/SKILL.md` applies them to policy pages, the
  control-to-evidence mapping, and the recorded reason for an exception.

The rules below govern text the writer is producing. For text written by another author, the
`prose-editor` agent template states the additional constraints that apply to an editor: the
minimum effective edit, and an audit mode that identifies patterns without rewriting.

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
- Often-empty adverbs: `just`, `simply`, `actually`, `literally`, `truly`, `fundamentally`,
  `importantly`, `crucially`, `inherently`, and `inevitably`. Remove each one whose deletion does
  not change the meaning. Retain those that express a genuine contrast or limitation, as
  `actually` does in "the flag is documented but is not actually read".

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
| At the end of the day... | Omit. |
| At its core... | Omit. |
| The reality is... / The truth is... | Omit and state the claim. |
| When it comes to X... | Make X the subject of the sentence. |
| In terms of X... / With regard to X... | Use a plain preposition: for, about, in. |
| In order to... | To. |
| Going forward... | Omit, or name the release or date it applies from. |
| In this article... / In this document... | Omit. |
| Let's dive in. | Omit. |

### The portability test

A sentence that could move unchanged into a document about a different tool, project, or
organization conveys no information about the present subject. Remove it, or replace it with a
fact, mechanism, consequence, or measurement specific to that subject.

"The integration improved efficiency" applies to any integration. "The integration reduced deploy
time from 40 minutes to 4" applies only to this one. Apply the same test to a claim of
importance, replacing "the tool significantly improves review quality" with the measured result.

## Word Choice

### Prefer

- Precise terminology.
- Concrete language.
- Domain-specific vocabulary where appropriate.
- Consistent naming conventions.

### Avoid

- Vague adjectives such as `very`, `really`, `quite`, and `somewhat` unless required.
- Clichés.
- Buzzwords without technical meaning.
- Ambiguous pronouns when the reference is unclear.
- Inflated, abstract verbs and adjectives common in generated text: `delve`, `leverage`,
  `utilize`, `facilitate`, `empower`, `streamline`, `underscore`, `foster`, `robust`, `seamless`,
  `pivotal`, `cutting-edge`, `multifaceted`, `meticulous`, `intricate`, `paramount`,
  `transformative`, `supercharge`, and `ever-evolving`. Use the plain, specific word the sentence
  needs instead (`use` rather than `utilize`, `rely on` rather than `leverage`).
- Inflated claims of significance: `paradigm shift`, `game changer`, `this is huge`, and
  `this changes everything`. State what changed and allow the reader to assess it.
- Filler nouns such as `landscape`, `realm`, `tapestry`, `beacon`, `synergy`, and `underpinnings`.
- Weak verb phrases where one direct verb exists: `made a decision` is `decided`,
  `has the ability to` is `can`, `provides support for` is `supports`, `serves as` is usually `is`.
- Formulaic transitions repeated across consecutive paragraphs, such as opening successive
  paragraphs with `Moreover`, `Furthermore`, `Additionally`, or `Notably`. Vary transitions, or
  omit them when the logical connection is already clear from the content.

The list above applies to these words used as inflation. Several of them are also established
technical terms, and in that use they are correct and should be retained: `harness` in "test
harness" and `elevation` in "privilege elevation" are examples. Determine whether the word
carries a specific technical meaning in the surrounding subject before removing it.

## Sentence and Paragraph Patterns

The following patterns are sentence and paragraph structures rather than individual words, so a
vocabulary check does not detect them. Each one occupies the position of a substantive statement
without making one, and each can therefore remain in a draft that satisfies every rule above.

| Pattern | Example | Replacement |
|---------|---------|-------------|
| Binary contrast | "This is not a lint failure. It is a design problem." | State the claim once: "The failure is in the design rather than the lint rule." |
| Throat-clearing opener | "Here is the thing," "Let me be clear," "To be honest," | Remove it and state the point. |
| False-insight setup | "What most people get wrong," "The part everyone misses," | Remove the setup and state the claim: "The cache key omits the lockfile hash." |
| Colon reveal | "The detail that makes it work: a second parser." | State it as a sentence: "A second parser is what makes it work." |
| Superficial analysis | "The release adds file search, highlighting the team's commitment to workflows." | Name the consequence: "The release adds file search, so a user can locate an earlier draft without leaving the editor." |
| Inflated significance | "marks a pivotal moment," "underscores its significance," "plays a vital role" | State the fact: "This is the project's first release with a stable API." |
| Interpretive metadiscourse | "That matters more than it sounds," "As you can see," "The key point is," | Remove it. Where the point is not already clear, supply the missing fact rather than a label. |
| Negative listing | "Not a linter. Not a formatter. A type checker." | "It is a type checker." |
| Sentence fragmentation for emphasis | "That is it. That is the whole change." | Use a complete sentence. |
| Rhetorical setup | "What if the cache is stale?", "Consider the following:", a question answered in the next sentence | State the point directly. |
| Pseudo-profound closing line | A closing metaphor or aphorism that restates the point as a flourish | Remove it and end on the most concrete sentence already present. |
| Summary-recap ending | A final paragraph restating the content of the document | End on the last concrete point, the conclusion, or the next action. |
| Uniform sentence rhythm | Repeated sentence structures, paragraphs of identical length, consecutive short fragments | Vary sentence structure where the variation aids comprehension. |

Two of these patterns affect the accuracy of a technical document rather than only its style:

- **Attribute or remove.** Replace "experts agree", "studies show", "it is widely regarded as",
  and "industry reports suggest" with a named source and a reference. Where no source exists,
  state the claim as the writer's own judgment or remove it. In a technical document, an
  unsourced appeal to consensus is an accuracy defect.
- **State the fact rather than labelling its importance.** Remove commentary describing a point as
  important, subtle, surprising, or obvious, and state the fact instead. Retain the specific
  measurement when doing so: "the change significantly improves throughput" omits the information
  contained in "the change reduced p99 latency from 800 ms to 120 ms".

## Formatting

- Use descriptive headings.
- Use numbered lists for sequential procedures.
- Use bullet lists for unordered information.
- Keep paragraphs focused on a single topic.
- Use tables only when they improve readability.
- Maintain consistent capitalization, formatting, and terminology.

Formatting follows the content rather than decorating it. Avoid the following:

- **Bullet lists used in place of prose.** Two or three related sentences belong in a paragraph.
  Reserve a list for items the reader will scan, compare, or return to.
- **Headings over very short sections.** A heading introducing two sentences adds navigation the
  document does not require. Merge the section, or extend it enough to justify the entry.
- **Bold applied mid-sentence for emphasis.** Reserve bold for a defined term or for the label
  beginning a list item. A sentence that requires bold for emphasis usually requires rewriting.
- **Emoji in headings**, which the Style section excludes from any position.

Use sentence case after a colon unless grammar, a proper noun, a title, or code requires
otherwise.

## Clarity

- State information directly.
- Avoid ambiguity.
- Explain technical concepts only when necessary for the intended audience.
- Define abbreviations on first use.
- Use examples only when they improve understanding.
- Prefer the concrete over the abstract: a name, a number, a date, a mechanism, or a consequence
  in place of a general statement about quality or scale.
- Use active voice with an identified subject. "The team shipped it on Tuesday" names the actor.
  "The decision emerged" does not. Do not assign a human verb to an inanimate subject.

## Consistency

- Use consistent terminology throughout the document.
- Use the same grammatical person and tense unless context requires otherwise.
- Follow the same formatting conventions throughout the document.
- Avoid switching between synonymous terms for the same concept.

Instructional and reference text uses the imperative and the third person. Write "Run the linter"
and "the caller supplies the path" rather than addressing the reader as "you" or speaking as "we".
Direct address is conversational, and mixing it with the imperative breaks the consistency rule
above. Two cases keep whatever person the original used: material quoted from another source,
including the title of a cited work, and an example of writing the document is instructing the
reader to avoid.

## Quality Checklist

Before producing the final output, verify that:

- The tone is formal and professional.
- The language is objective and precise.
- No em dashes (`—`) are present.
- No arrow symbols (`→`) are present in prose. Arrows inside diagrams, mapping tables,
  code, or command output are acceptable.
- No conversational fillers remain.
- No inflated generated-text markers (`delve`, `leverage`, `utilize`, `underscore`, `robust`,
  `seamless`, and similar) or formulaic transitions (`Moreover`, `Furthermore`) repeated across
  paragraphs.
- Every sentence adds meaningful information.
- Every sentence passes the portability test, or has been made specific to this subject.
- No pattern listed under Sentence and Paragraph Patterns is present, including binary contrast,
  throat-clearing opener, false-insight setup, colon reveal, inflated significance, interpretive
  metadiscourse, negative listing, sentence fragmentation, and rhetorical setup.
- Every claim of consensus names a source, or has been removed.
- The document ends on a concrete point, a conclusion, or a next action, with no recap paragraph
  and no closing flourish.
- Formatting follows the content: no bullet list in place of prose, no heading over a
  two-sentence section, and no bold applied mid-sentence for emphasis.
- Sentence structure varies, with no consecutive fragments and no repeated paragraph template.
- Redundant words and repeated ideas have been removed.
- Grammar and punctuation are correct.
- Terminology is consistent.
- The document is concise, clear, and easy to read.
