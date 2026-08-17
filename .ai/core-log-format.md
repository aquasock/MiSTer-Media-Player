# core-log.md Entry Format

Normative formatting rules for `core-log.md`. Read this before writing a log
entry. `core.md` remains authoritative for policy; this document governs the
shape of entries only.

The rule this document exists to enforce: **an entry has exactly six sections,
in a fixed order, and nothing else.** Every past formatting failure in this
project has been an agent inventing a seventh.

---

## Canonical Template

Copy this. Do not add to it.

```markdown
## 132 COMMIT v0.5.0 194cfb6 2026-08-15T01:17:18-07:00

#### Coming From:

v0.5.0 1dd8382

#### Purpose:

(Single sentence statement)

#### Outcome:

(Standard english paragraph)

#### Next Steps:

(Standard english paragraph)

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv

#### Status:

- [x] Built
- [ ] Passed

---
```

---

## Header Line

`## <number> <type> <version> <short-hash> <timestamp>`

| Field | Rule |
|---|---|
| `<number>` | Sequential, no zero padding. Roll over to `001` after `999`. |
| `<type>` | `COMMIT` or `VERSION`. These are the only two record types. See below. |
| `<version>` | `Unreleased`, or the semantic version tag once released, e.g. `v0.5.0`. |
| `<short-hash>` | Abbreviated SHA of the commit this entry records, or `???` while the commit does not exist yet. Never a full SHA. |
| `<timestamp>` | ISO-8601 with local UTC offset, America/Phoenix, e.g. `2026-08-15T01:17:18-07:00`. |

One space between fields. No punctuation, no parentheses, no trailing text.

### Record Types

`COMMIT` — an ordinary development commit. `<version>` is `Unreleased` until the
work is included in a release.

`VERSION` — a published version boundary: the tag, GitHub release, and packaged
binary described in the Releasing section of `core.md`. `<version>` carries the
semantic version tag, e.g. `v0.5.0`. Use this for release qualification and
publication records so a reader can find every release boundary by scanning for
one keyword.

`COMMIT` and `VERSION` are the only two record types. Do not invent others.
There is no separate proposal type — a proposal is an ordinary entry whose
commit does not exist yet.

### The `???` Hash Placeholder

An entry is written **before** its work is committed, so that the plan is on
record and can be approved. Until the commit exists, the hash field is the
literal `???`:

```markdown
## 184 COMMIT Unreleased ??? 2026-08-17T03:14:22-07:00
```

Write the entry in full at proposal time — Purpose, Outcome, Next Steps, Files
Modified and Status are all filled in as the plan, with both Status boxes
unchecked. Once the commit is made, replace `???` with the real abbreviated SHA
and update the entry to record what actually happened.

Replacing `???` with the real hash is a required update, not a rewrite of
history. It is the one edit always permitted to an existing entry.

Exactly one entry may carry `???` at a time. A second `???` means a proposal was
abandoned without being resolved; correct it before writing a new one.

---

## The Six Sections

All six are mandatory, in this order. A section with nothing to say still
appears; write `None.` as its body rather than omitting the heading.

Leave one blank line after every `####` heading, exactly as the template shows.

### 1. Coming From:

The version and short hash of the entry this one follows: `Unreleased 1dd8382`.
Two tokens, one line. This is what makes the log a chain rather than a pile.

### 2. Purpose:

**One sentence.** What this commit was for. Not what happened, not how it went —
that is Outcome. If a second sentence is needed, the commit boundary is probably
too wide.

### 3. Outcome:

A standard English paragraph describing what the commit did and how it turned
out. Prose only.

No tables. No bullet lists. No code blocks. No headings. Inline backticks for
identifiers and hashes are fine.

Keep it to what a future agent needs in order to understand the project's state.
Detailed evidence does not belong here — see "Where Detail Goes".

### 4. Next Steps:

A standard English paragraph stating what should happen next. Same prose-only
rule as Outcome. In a `???` entry this states the plan and the validation the
work will need; once the commit exists, update it to point at the following
cycle.

### 5. Files Modified:

A bullet list of repository-relative paths, one per line, `- ` prefix. Source
files only — do not list `.ai/` metadata files, build outputs, or generated
binaries. If a build correction changed the file set, list the final set that
the recorded hash actually contains.

### 6. Status:

Exactly two lines. Exactly this text:

```markdown
- [x] Built
- [ ] Passed
```

**No suffixes.** No em dash, no parenthetical, no hash, no slack figures, no
explanation of why a box is unchecked. `Built` means the commit compiled
cleanly; `Passed` means hardware validation accepted it. The reason a box is
unchecked belongs in Outcome or Next Steps, as prose.

Do not add a third box. Do not rename the boxes.

Close the entry with `---` on its own line.

---

## Where Detail Goes

`core-log.md` is a bounded ring buffer that a recovering agent reads in full. It
is an index of project state, not an evidence archive. Long-form detail belongs
in the **git commit message**, which is unbounded, permanent, and already tied to
the exact hash the entry names.

| Content | Destination |
|---|---|
| Timing figures, utilization, slack tables | Commit message |
| Hardware result tables, LED codes, per-stream readings | Commit message |
| Root-cause analysis, ruled-out hypotheses, traces | Commit message |
| Photographs, captures, measurements | `.ai/current_results/` |
| One-paragraph summary of the above | `core-log.md` Outcome |

If an entry's Outcome runs past roughly one screen, the detail has leaked into
the wrong file.

---

## Numbering And The Ring Buffer

Per `core.md`, `core-log.md` holds a bounded number of the most recent entries;
when the limit is exceeded, remove entries from the top. Entry numbers keep
increasing regardless, rolling `999` to `001`.

Before pruning, prefer to roll an entry off only when both of its Status boxes
are resolved. Dropping the opening entry of a still-open investigation removes
the context that explains why current work is happening, which is the most
expensive kind of loss for a recovering agent.

---

## Commit Messages For The Log Itself

Per `core.md`, use `(current_short_commit) core-log.md update`, where
`current_short_commit` is the abbreviated SHA of the source commit this
development cycle produced. Metadata-only `.ai/` commits do not advance that
value, so several consecutive log updates may carry the same hash.

---

## Prohibited

1. **Any section heading other than the six above.** This is the dominant
   failure mode. Real examples already in this log that must not recur:
   `Diagnostic Result`, `Validation`, `Evidence`, `Interpretation`, `Scoping`,
   `Build Correction`, `Hardware Result`, `Implementation`, `Critical Scope
   Finding`, `Ruled Out By Static Analysis`, `Proposed Commit Boundary`,
   `Photographic Evidence`, `Follow-on`, `Build`. All of these are Outcome or
   Next Steps written as prose.
2. Suffixes or annotations on Status lines.
3. Tables, bullet lists, or code blocks inside Purpose, Outcome, or Next Steps.
4. Omitting a mandatory section.
5. Full SHAs in the header line.
6. Editing a settled entry to change history. Corrections are made by writing
   the correction into the current entry's Outcome, naming the superseded entry.
   Replacing a `???` placeholder with its real hash, and completing that entry
   once its commit exists, are the permitted exceptions.
7. Appending to an entry after its hash is recorded. If new information arrives
   after that point, it belongs to the next entry.
8. More than one `???` entry in the log at a time.

---

## Checklist

Before committing a log update, verify:

- [ ] Header has five fields, type is `COMMIT` or `VERSION`, ISO-8601 with `-07:00`
- [ ] Hash is a real abbreviated SHA, or `???` if the commit does not exist yet
- [ ] No second `???` entry already in the log
- [ ] If this commit resolves a `???` entry, the placeholder was replaced
- [ ] Exactly six `####` sections, in template order, none added
- [ ] Blank line after every heading
- [ ] Purpose is one sentence
- [ ] Outcome and Next Steps are prose, no tables or lists
- [ ] Files Modified lists source paths only
- [ ] Status is exactly two lines with no suffixes
- [ ] Entry ends with `---`
- [ ] Entry count is within the ring-buffer limit
- [ ] Commit message is `(current_short_commit) core-log.md update`

---

## Current Log Conformance

As of 2026-08-17 the existing `core-log.md` does not conform. An audit found 26
distinct section headings in use against the six permitted, and 22 of 41 Status
lines carrying forbidden suffixes. Mandatory sections are frequently absent:
`Coming From` appears in 9 of 20 entries, `Files Modified` in 8, `Next Steps` in
5.

Entries 176 through 183 are the worst offenders and were written by an agent
that invented a new heading whenever the evidence did not fit the template,
rather than compressing the evidence into Outcome and moving the detail into the
commit message.

Existing entries are historical record and should not be rewritten. This format
applies to every entry written from now on.
