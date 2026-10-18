# Yavito: Yet Another VIm-like Text Object

Vim-inspired text objects for ordinary Emacs regions.

Select a word, paragraph, or enclosing pair from wherever you are inside it,
then use the Emacs commands you already know: `kill-region`,
`copy-region-as-kill`, `indent-region`, `eval-region`, and more.

Yavito borrows Vim's text object vocabulary without introducing an editing
mode or operator grammar. Familiar behavior is kept where practical; irregular
special cases are simplified.

## Why Yavito exists

I moved from Vim to Emacs and came to enjoy modeless editing, especially
when writing long stretches of text. I could keep writing, move around, and
invoke commands without switching editing modes.

But I kept running into one small frustration: my cursor would be somewhere
inside the thing I wanted to select. A word, a paragraph, or an expression
inside parentheses. I knew which object I wanted; selecting it still meant
working out how to reach its boundaries.

Emacs already has the building blocks. For a word, I could use
`M-b C-SPC M-f`; for expressions, commands such as `C-M-f` help navigate
structure. With the right sequence of movement and marking commands, I could
get the region I needed. It just felt like too much choreography for such a
simple intention: “select the thing I'm inside.”

That was what I missed about Vim's text objects. `iw`, `a(`, and friends let
me name the object directly, without first moving to one end of it.

I considered Evil, but I wanted to keep the modeless workflow I had grown
to enjoy. Bringing back modal editing would change more of my editing habits
than I wanted to change just to get text objects back.

So Yavito brings that part of Vim into an Emacs workflow: name an object,
select it as an ordinary region, and let Emacs handle the next action.
`C-w` cuts it, `M-w` copies it, and `eval-region` evaluates it. The same
selection works with any command that accepts a region.

## Quick start

Bind the selector to a key, such as `C-;`, then type an object expression:

| Keys | Selection |
| --- | --- |
| `C-; iw` | Current word |
| `C-; iW` | Current run of non-whitespace characters |
| `C-; a(` | Enclosing parentheses, including both delimiters |
| `C-; i)` | Contents of the enclosing parentheses |
| `C-; 2i(` | Contents of the second enclosing parenthesis pair |
| `C-; is` | Contents of the nearest enclosing pair of any supported type |
| `C-; 2iw` | Current word and the next word |
| `C-; -2iw` | Current word and the previous word |
| `C-; il` | Current line without leading indentation or its final newline |
| `C-; ap` | Current paragraph with adjacent separating whitespace |

For example, with the cursor at `|`:

```text
one t|wo three four
```

`C-; 2iw` selects `two three`. Follow it with `M-w` to copy or `C-w`
to cut. The first word is selected in full even when the cursor starts in
its middle.

## Installation

Requires **Emacs 27.1 or later**. No third-party runtime dependencies.

Clone the repository into a directory on your `load-path`:

```sh
git clone https://github.com/shiori-route/yavito.git ~/.emacs.d/site-lisp/yavito
```

Then add this to your configuration:

```elisp
(add-to-list 'load-path
             (expand-file-name "~/.emacs.d/site-lisp/yavito"))
(autoload 'yavito-select "yavito" nil t)
(global-set-key (kbd "C-;") #'yavito-select)
```

With `use-package`:

```elisp
(use-package yavito
  :ensure nil
  :load-path "~/.emacs.d/site-lisp/yavito"
  :bind ("C-;" . yavito-select))
```

Yavito does not install a global key binding itself; the examples use
`C-;` as a suggested entry point.

### As a Git submodule

From your Emacs configuration repository:

```sh
git submodule add git@github.com:shiori-route/yavito.git packages/yavito
```

Set `:load-path` to that directory. After cloning a configuration that
already contains the submodule, initialize it with:

```sh
git submodule update --init --recursive
```

## Input syntax

```text
C-; [-][count] i|a object
```

- `i` selects the object's interior.
- `a` selects the whole object, including delimiters or adjacent whitespace
  as appropriate for that object.
- The count defaults to `1` and is typed directly after `C-;`; no `C-u`
  is needed. Zero is invalid.
- `C-g` cancels input.

### Objects

| Object | Inner (`i`) | Around (`a`) |
| --- | --- | --- |
| `w` | A word or a run of punctuation | Also includes adjacent horizontal whitespace |
| `W` | A run of non-whitespace characters | Also includes adjacent horizontal whitespace |
| `l` | Line content, excluding initial indentation and final newline | Whole line, including indentation and final newline when present |
| `p` | Paragraph content | Also includes adjacent separating whitespace |
| `(` or `)` | Contents of parentheses | Includes parentheses |
| `[` or `]` | Contents of square brackets | Includes square brackets |
| `{` or `}` | Contents of braces | Includes braces |
| `"`, `'`, or backtick | Contents of a matching quote pair | Includes quotes and adjacent horizontal whitespace |
| `s` | Contents of the nearest enclosing pair | Whole enclosing object; quotes also use their whitespace rule |

Opening and closing bracket keys are interchangeable: `i(` and `i)`
select the same range.

For words, forward `a` selection prefers trailing whitespace and falls back
to leading whitespace; backward selection reverses that preference. Quote
objects prefer trailing whitespace, then leading whitespace. Paragraphs
prefer following separating whitespace, then preceding whitespace.

### Counts and direction

For **words, WORDs, lines, and paragraphs**, the count is the total number
of objects selected. The current object is included in full. Positive counts
extend toward the end of the buffer; negative counts extend toward its start.
Word separators are included between selected words but do not count as words.

```text
one two th|ree four five

 2iw  → three four
-2iw  → two three
-3iw  → one two three
```

For **enclosing objects**, the count selects an outer layer. A specific
bracket key counts only pairs of that type; `s` counts all supported types:

```text
(outer [inner "va|lue"])

 is   → value
 2is  → inner "value"
 3as  → (outer [inner "value"])
```

Negative enclosing counts use their absolute value and display a non-blocking
warning: `-2i(` behaves exactly like `2i(`. Repeated quote characters do not
form nested quote layers, so a second enclosing quote layer is normally
unavailable.

For multiple lines, `i` removes only the selected range's initial indentation
and final newline. Intermediate indentation and newlines are preserved.

## Region behavior

Successful selection activates a normal Emacs region. Forward selections put
point at the end and mark at the beginning; backward linear selections reverse
those positions. Subsequent Emacs commands can operate on or adjust the region.

An existing selection is replaced using the current point as the reference;
repeating the command does not implicitly expand the previous selection.

Enclosing objects must contain point, including a delimiter character at point.
Yavito does not jump to a later pair when you are outside one. Missing objects,
insufficient counts, and invalid input leave point and mark unchanged.
An empty interior such as `()` is valid and produces a zero-length region.

## Vim compatibility and MVP limits

Yavito aims for familiar text object behavior, rather than complete Vim
compatibility. Deliberate differences include:

- Word counts count words, not intervening whitespace units.
- `2i"` means a second enclosing quote layer; it does not switch to including
  quote delimiters.
- Enclosing selection does not search ahead from outside an object, and empty
  interiors are allowed.
- Counts can be negative, and selection produces an Emacs region instead of
  entering Visual mode or applying an operator.

The MVP uses character-based matching:

- Quotes pair within a single line. Quotes preceded by an odd run of
  backslashes are escaped. Apostrophes in prose can affect single-quote pairing.
- Brackets can span lines. Brackets inside quoted ranges are ignored.
  Language-specific string and comment syntax is not interpreted.
- `w` groups letters, digits, and underscores separately from punctuation;
  Vim's configurable `iskeyword` behavior is not exposed.
- Paragraphs are separated by blank lines, independently of major-mode
  paragraph settings.
- Word whitespace handling covers spaces and tabs; Vim's full cross-line
  whitespace behavior is not reproduced.
- Object lookup respects narrowing and currently scans the accessible buffer.
  Large-buffer performance has not been optimized.

## Roadmap

Planned extensions include replacing enclosing delimiters, removing a pair,
and adding a pair around an existing region. For example, replacing `(abc)`
with `[abc]` would reuse the same enclosing-object lookup.

These editing operations are not part of the current MVP. Character jumps
such as Vim's `f` and `t` are also outside its current scope.

## Development

```sh
make test
make compile
```

The ERT suite covers selection counts and direction, nested and mixed enclosing
objects, bracket aliases, escaped quotes, empty interiors, lines and paragraphs,
input parsing, cancellation, and preservation of state on failure. Compilation
treats warnings as errors.

## License

[GNU General Public License, version 3 or later](LICENSE).
