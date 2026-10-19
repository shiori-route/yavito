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
| `C-; iS` | Contents of the nearest enclosing pair of any supported type |
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

### Automatic installation with `use-package`

On **Emacs 30.1 or later**, use the built-in `:vc` support to clone and
install Yavito directly from GitHub:

```elisp
(use-package yavito
  :ensure t
  :vc (:url "https://github.com/shiori-route/yavito.git"
       :rev :newest)
  :bind ("C-;" . yavito-select))
```

When Yavito is not installed, evaluating this declaration fetches and installs
it automatically. `:rev :newest` selects the latest commit rather than the
last release. Git must be available on your system. See the
[use-package installation manual](https://www.gnu.org/software/emacs/manual/html_node/use-package/Install-package.html)
for details.

### Manual installation

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
| `s` | Sentence content | Also includes adjacent separating whitespace |
| `(`, `)`, or `b` | Contents of parentheses | Includes parentheses |
| `[` or `]` | Contents of square brackets | Includes square brackets |
| `{`, `}`, or `B` | Contents of braces | Includes braces |
| `"`, `'`, or backtick | Contents of a matching quote pair | Includes quotes and adjacent horizontal whitespace |
| `<` or `>` | Contents of angle brackets | Includes angle brackets |
| `t` | Contents between matching HTML/XML tags | Includes opening and closing tags |
| `S` | Contents of the nearest enclosing pair | Whole enclosing object, including tag blocks; quotes also use their whitespace rule |

Opening and closing bracket keys are interchangeable: `i(` and `i)`
select the same range. `b` aliases parentheses and `B` aliases braces.
Lowercase `s` means sentence, matching Vim; uppercase `S` is Yavito's generic
surround object.

For words, forward `a` selection prefers trailing whitespace and falls back
to leading whitespace; backward selection reverses that preference. Quote
objects prefer trailing whitespace, then leading whitespace. Paragraphs and sentences
prefer following separating whitespace for forward selection, and preceding
whitespace for backward selection, falling back to the other side.

### Counts and direction

For **words, WORDs, lines, paragraphs, and sentences**, the count is the total number
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
bracket key counts only pairs of that type; `S` counts all supported types:

```text
(outer [inner "va|lue"])

 iS   → value
 2iS  → inner "value"
 3aS  → (outer [inner "value"])
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

For example, inside `(foo "hello (wo|rld)")`, `i(` selects `world`, `a(`
selects `(world)`, and `2a(` selects the whole outer expression. If the
string contains no enclosing literal pair, selection starts with the outer
code pair instead. Counts for a specific bracket type continue to count
only that type; generic `S` can also include the quote object.

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
- Brackets can span lines. Matching respects the current mode's syntax table
  and syntax properties. From code, strings and comments do not contribute
  bracket pairs. From inside a string, literal pairs in that same string are
  included before enclosing code pairs. Separate stacks prevent unmatched
  literals or brackets in other strings from consuming code delimiters.
  Comment brackets remain ignored. Quote text objects themselves remain
  character-based.
- `w` groups letters, digits, and underscores separately from punctuation;
  Vim's configurable `iskeyword` behavior is not exposed.
- Sentences end at `.`, `!`, or `?`, followed by optional closing brackets
  or quotes and whitespace or a paragraph boundary. This uses Vim-style ASCII
  punctuation, independently of major-mode settings and Vim's `cpoptions`.
- Tags match case-insensitively. Comments, CDATA, processing instructions,
  self-closing tags, HTML void tags, and stray closing tags are skipped. This
  is a lightweight matcher, not a full HTML/XML parser.
- Angle brackets are matched mechanically; comparison operators can therefore
  look like angle-bracket pairs.
- Paragraphs are separated by blank lines, independently of major-mode
  paragraph settings.
- Word whitespace handling covers spaces and tabs; Vim's full cross-line
  whitespace behavior is not reproduced.
- Object lookup respects narrowing. Words, lines, and paragraphs are found
  locally; sentence lookup scans the current paragraph. Bracket and tag
  providers still scan the accessible buffer; no parse cache is maintained.

## Extending text objects

Three customizable tables separate keys, object semantics, and parsing backends:

| Variable | Responsibility |
| --- | --- |
| `yavito-object-keys` | Input character to symbolic object name, or character alias |
| `yavito-object-types` | Object name to definition, count kind, handler, and optional candidate provider |
| `yavito-object-providers` | Backend overrides for an existing object, independently of its keys |

All can be set buffer-locally. First entries take precedence. Automatic
major-mode inheritance and registry merging are still planned.

### Keys and definitions

Assign another key to an existing object:

```elisp
(with-eval-after-load 'yavito
  (add-to-list 'yavito-object-keys '(?r . paragraph)))
```

Character aliases such as `(?r . ?p)` also work; cycles are rejected. Object
names remain independent of key choices. The input prompt reads the key table.

Define a new object by returning structured ranges:

```elisp
(defun my-yavito-buffer-object (spec _count _around)
  "Return the accessible buffer as a text object."
  (let ((range (cons (point-min) (point-max))))
    (yavito-object-create (plist-get spec :name) range range)))

(with-eval-after-load 'yavito
  (add-to-list 'yavito-object-types
               '(entire-buffer :kind linear
                               :handler my-yavito-buffer-object))
  (add-to-list 'yavito-object-keys '(?e . entire-buffer)))
```

The handler receives the resolved definition (including `:name`), count, and
around flag. `:kind linear` receives signed counts; negative counts reverse
region direction. `:kind enclosing` receives absolute counts and uses the
negative-count warning. The handler owns object-specific count and whitespace
rules. The entire-buffer example deliberately selects the same range for any
count or `i/a` request.

### Structured results and providers

Handlers return a plist with symbolic `:type`, `:inner`, and `:outer` ranges.
Each range is `(BEGIN . END)` with an exclusive end; the inner range must lie
inside the outer range, and both must respect narrowing. Signal `user-error`
when no object exists. Handlers must not edit buffer contents. Point, mark,
narrowing, and match data are preserved during lookup.

`yavito-object-at-point` returns the structured object; `yavito-bounds` keeps
the simpler range API by choosing `:inner` or `:outer` from that result.

A buffer-local `yavito-object-providers` entry can override `:handler` and/or
`:candidates` for an object such as `function`, without changing its keys.
The object definition must already exist. This interface is available now;
actual mode and Tree-sitter adapters are still planned.

### Participating in generic surround

An enclosing definition can register a zero-argument `:candidates` function
that returns a list of structured objects. It can return all objects or only
those containing point. Providers shared by several definitions are called
once per surround query. `S` gathers these candidates, deduplicates equal
structural extents, and follows a true containment chain. Crossing ranges do
not become additional outer layers; ties preserve provider order.

An optional `:extent` range records structural boundaries when `:outer` also
includes adjacent whitespace. It must enclose `:inner` and be contained in
`:outer`. Without it, `:outer` is used for nesting. Custom handlers without a
candidate provider remain selectable by their own key and do not enter `S`.

Built-in delimiter definitions use `:open` and `:close`, or `:open` and
`:quote t` for same-line quotes. Their shared provider returns structured
objects just like the tag provider; the generic surround code has no fixed
list of object types.

The earlier MVP used character-keyed `yavito-object-types` entries with
`:bounds` callbacks. That experimental format has been replaced by the three
tables and structured handler results above. Existing `yavito-select` and
`yavito-bounds` calls remain supported.

## Roadmap

Planned extensions include replacing enclosing delimiters, removing a pair,
and adding a pair around an existing region. For example, replacing `(abc)`
with `[abc]` would reuse the same enclosing-object lookup.

Language- and mode-aware objects are also planned:

- **Tree-sitter code objects:** functions, classes, blocks, arguments, and
  expressions, with language-specific definitions of inner and whole ranges.
- **TeX/LaTeX objects:** matching `\begin{...}` / `\end{...}` environments
  and inline or display math, including `$...$`, `$$...$$`, `\(...\)`, and
  `\[...\]` delimiters.
- **Markdown objects:** fenced code blocks, inline code, links, and sections;
  math objects where the mode supports a math extension.

Mode-specific objects should extend the default registry, with buffer-local
customizations taking precedence. Tree-sitter will be an optional backend;
mode adapters may also use their existing parsers. The provider override
interface exists; language adapters and automatic mode-registry merging are
not implemented yet. Keys for
these additional objects have not been assigned yet.

These editing operations are not part of the current MVP. Character jumps
such as Vim's `f` and `t` are also outside its current scope.

## Development

### Source layout

| File | Responsibility |
| --- | --- |
| `yavito.el` | Public interactive entry point, input reading, and region activation |
| `yavito-core.el` | Key/definition/provider registries, alias resolution, and object dispatch |
| `yavito-range.el` | Structured object results, range validation, and generic whitespace utilities |
| `yavito-linear.el` | Words, lines, paragraphs, sentences, and signed selection counts |
| `yavito-enclosing.el` | Brackets, quotes, enclosing layers, and generic `S` selection |
| `yavito-tags.el` | HTML/XML tag range matching |
| `test/yavito-test.el` | Regression tests for the public behavior and extension interface |

`yavito` loads the core and range model; registered handlers and candidate
providers load their implementation modules on demand. Internal modules do
not depend on the interactive entry point. Future mode and Tree-sitter
adapters can build on the core without handling keyboard input themselves.

### Checks

```sh
make test
make compile
make clean  # remove generated bytecode
```

The ERT suite covers selection counts and direction, nested and mixed enclosing
objects, crossing/duplicate surrounds, independent and escaped quotes, empty
interiors and lines, provider overrides, structured results, local traversal,
input parsing, cancellation, and preservation of state on failure. Compilation
treats warnings as errors.

## License

[GNU General Public License, version 3 or later](LICENSE).
