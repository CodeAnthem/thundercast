# Bash Interactive Prompt Utility — Design Specification

## 1. Goal

Design a **single, general-purpose Bash function** for interactive user prompts.

The function is intended to handle situations where a Bash script needs to interactively ask the user for:

* free-form text
* hidden/secret input
* masked input
* yes/no confirmation
* a single choice
* multiple choices
* multiline text
* navigation actions such as Back, Cancel, and Proceed

The utility should be a **low-level interaction primitive**, not a validation framework and not an application workflow engine.

The central principle is:

> **The prompt utility handles user interaction. The calling script handles meaning, validation, business logic, and workflow.**

---

# 2. Separation of Responsibilities

The prompt utility should:

* display the prompt
* collect keyboard input
* provide interactive UI
* handle selection/navigation
* handle hiding/masking
* handle defaults
* handle multiline termination
* expose configurable interaction actions
* return structured results

The prompt utility should **NOT**:

* validate domain-specific values
* perform regex validation
* check numeric ranges
* check whether a path is valid
* check whether a file exists
* transform user input
* trim whitespace automatically
* convert case
* decide whether an answer is acceptable
* decide what "Back" means
* perform application logic
* execute commands
* modify files
* implement multi-step workflows

Validation belongs to the caller.

Example conceptual flow:

```text
prompt
  ↓
user input
  ↓
calling script validates
  ↓
valid → continue
invalid → display error → prompt again
```

The prompt itself should not know why a value is valid or invalid.

---

# 3. Fundamental Prompt Model

Conceptually:

```text
PROMPT
    = interaction type
    + presentation
    + initial state/default
    + interaction controls
    → result
```

The utility should be designed around **interaction types**, not around application-specific data types.

---

# 4. Prompt Types

The initial supported types should be:

### `text`

Single-line free-form text input.

Example:

```text
Project name:
```

---

### `multiline`

Multiple lines of free-form text.

Example:

```text
Description:
line one
line two
line three
DONE
```

The caller specifies the terminating line.

---

### `select`

Single-choice selection.

Example:

```text
Select environment:

1. Development
2. Staging
3. Production
```

Returns the selected option's **value/ID**, not its display label.

---

### `multi-select`

Multiple-choice selection.

Example:

```text
Select features:

☐ Git
☑ Docker
☐ Kubernetes
☑ CI
```

The user can toggle multiple items and then submit the selection.

Returns the selected option values/IDs.

---

### `confirm`

Boolean confirmation.

Example:

```text
Delete everything? [y/N]
```

Returns a semantic yes/no result.

A "no" answer is still a **successful prompt interaction**, not an error.

---

# 5. Core Arguments

## `--type`

Defines the interaction type.

Supported values:

```text
text
multiline
select
multi-select
confirm
```

`text` can be the default if no type is specified.

---

## `--message`

The main prompt/question displayed to the user.

This is the primary human-facing text.

---

# 6. Default Value

## `--default VALUE`

Defines what happens when the user submits without entering a value.

Example:

```text
Port [8080]:
```

If the user presses Enter, the result is `8080`.

Important:

* `default` is a fallback value.
* There is **no `--initial` option**.
* The utility does not need a separate concept for an editable initial value.

If `--default` and `--allow-empty` conflict, the exact precedence should be explicitly defined by the implementation/specification.

---

# 7. Empty Input

## `--allow-empty`

Controls whether the user may submit an empty input.

This is the **only input-policy concept intentionally handled by the prompt itself**.

The prompt should distinguish:

```text
empty input
cancelled
EOF/error
```

These are different states.

The utility should not otherwise decide whether the content is "valid."

For example, whether `"   "` should be considered empty is an application decision unless the prompt specification explicitly defines otherwise.

---

# 8. Hidden and Masked Input

There should NOT be a special `--password` prompt type.

Instead, visibility is a general property of the interaction.

## `-H`, `--hide`

Do not visually echo the user's input.

This should work with any prompt type where hiding input makes sense.

Examples:

```text
prompt --hide "API token"
```

or:

```text
prompt --type multiline --hide "Private key"
```

The utility should not care whether the hidden value is technically a password, token, private key, PIN, etc.

`--hide` means:

> The user's input should not be displayed.

---

## `--mask CHARACTER`

Instead of hiding the input completely, display a masking character for each entered character.

Example:

```text
Token: ************
```

`--mask` and `--hide` represent two different visual modes.

There is **no reveal feature**.

No `--show`, reveal key, or temporary reveal mechanism is required.

---

# 9. Multiline Input

`multiline` is an interaction type.

Example:

```text
prompt --type multiline --end "DONE" "Enter description"
```

The user enters:

```text
This is line one.
This is line two.
This is line three.
DONE
```

The returned value is:

```text
This is line one.
This is line two.
This is line three.
```

---

## `--end STRING`

Defines the exact line that terminates multiline input.

Rules:

* the terminator must occupy an entire line
* comparison is exact
* the terminator is not part of the returned value by default
* empty lines are allowed
* the caller chooses the terminator
* there should not be a magical hardcoded terminator

This is particularly useful for pasted content such as private keys.

Example:

```text
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
PROMPT_DONE
```

The caller can specify:

```text
--end "PROMPT_DONE"
```

so that the actual private-key ending remains part of the returned value.

---

## `--include-end`

Controls whether the terminating line itself is included in the returned result.

Default:

```text
include-end = false
```

Without it:

```text
hello
world
DONE
```

returns:

```text
hello
world
```

With `--include-end`, it returns:

```text
hello
world
DONE
```

This is important for cases where the final line is meaningful data, such as pasted structured content.

---

# 10. Selection Options

For `select` and `multi-select`, choices should be represented as structured options.

Each option should conceptually have:

```text
value
label
description
```

For example:

```text
value: prod
label: Production
description: Live production environment
```

The user sees:

```text
Production
Live production environment
```

but the script receives:

```text
prod
```

The **value** is what matters to the calling script.

---

# 11. `--options`

Provides the available choices.

The exact serialization format is an implementation detail, but the design must support at minimum:

```text
value
label
description
```

Optional future properties could include:

```text
disabled
group
shortcut
```

but these are not required for the core implementation.

---

# 12. `--selected`

For `multi-select`, defines which options are initially selected.

Example:

```text
Git       ☑
Docker    ☑
Kubernetes ☐
CI        ☐
```

The calling script supplies the initial selection.

There should be no validation rules such as minimum/maximum selection counts in the prompt utility.

If the script requires at least two selections, the script validates that after receiving the result and calls the prompt again if necessary.

---

# 13. Multi-Select Keyboard Model

Default interaction:

```text
↑ / ↓      navigate
Space      toggle current item
Enter      submit
Esc        cancel
```

Example:

```text
Select features:

☐ Git
☑ Docker
☐ Kubernetes
☑ CI

↑/↓ move   Space select   Enter continue   Esc cancel
```

Space changes selection state.

It does **not** submit the prompt.

Enter submits the current selection by default.

---

# 14. Actions

A key design concept is that **submission/navigation actions should be separate from the selected/input value**.

The utility should support semantic actions such as:

```text
submit
back
cancel
help
```

Potential future actions:

```text
clear
select-all
deselect-all
```

The caller should be able to configure which keyboard key triggers an action.

---

# 15. Configurable Key Bindings

Use a generic binding concept rather than creating a separate flag for every possible key.

Conceptually:

```text
--bind ACTION=KEY
```

Examples:

```text
--bind submit=x
--bind back=b
```

This allows the caller to customize the interaction.

The prompt utility interprets the key and returns the corresponding semantic action.

It should NOT make the caller interpret raw keyboard characters.

---

# 16. Example: Custom Back/Proceed Menu

A caller might want:

```text
Select ...

1. hello
2. another option
3. auto

B = back
X = proceed
```

The prompt could be configured conceptually as:

```text
type = select
options = hello, another option, auto
bind back = b
bind submit = x
```

Then:

```text
1 → select hello
2 → select another option
3 → select auto
B → action: back
X → action: submit
```

The caller receives semantic results such as:

```text
ACTION = back
```

or:

```text
ACTION = submit
VALUE = auto
```

The prompt utility does not know what "back" means.

The calling application decides:

```text
back → go to previous step
submit → continue workflow
```

---

# 17. Default Keyboard Bindings

The utility should have sensible defaults.

### Text

```text
Enter → submit
Esc   → cancel
```

### Multiline

```text
Enter → new line
terminator → submit
Esc → cancel
```

### Select

```text
↑ / ↓ → navigate
Enter → submit
Esc → cancel
```

### Multi-select

```text
↑ / ↓ → navigate
Space → toggle
Enter → submit
Esc → cancel
```

### Confirm

```text
y → yes
n → no
Enter → configured default
Esc → cancel
```

These are defaults, not immutable behavior. Bindings can be overridden.

---

# 18. Numbered Selection

Selection menus should support numbered options.

Example:

```text
Select ...

1. hello
2. another option
3. auto
```

Number keys can act as direct option selection.

The recommended behavior is:

```text
1 → select option 1
2 → select option 2
3 → select option 3
```

and **do not automatically submit** unless the caller explicitly configures that behavior.

This allows:

```text
1 → choose
X → submit
```

when custom actions are used.

The prompt must distinguish option-selection keys from action keys.

Example:

```text
1, 2, 3 → options
B        → back
X        → submit
```

---

# 19. Cancellation

Cancellation must be a first-class result.

The prompt should distinguish at least:

```text
successful input
empty input
cancel
EOF
error
```

Cancellation should not be confused with empty input.

For example:

```text
Enter
```

can mean an empty value when `allow-empty` is enabled.

Whereas:

```text
Esc
```

means cancellation.

The caller decides what cancellation means for its workflow.

---

# 20. Presentation

The utility may control UI presentation, because this is part of interaction.

Potential arguments:

### `--description`

Additional explanatory text.

Example:

```text
Choose deployment environment
This determines which credentials will be used.
```

---

### `--placeholder`

A visual hint for text input.

It is not the returned value.

---

### `--prefix`

Optional prompt prefix.

Example:

```text
? Project name:
```

---

### `--suffix`

Optional suffix.

---

### `--footer`

Additional instructions displayed below the interaction.

For example:

```text
↑/↓ move   Space select   X proceed   B back
```

---

### `--plain`

Disable fancy terminal UI.

Useful for simpler terminals, CI environments, logging, etc.

---

### `--no-color`

Disable color output.

Important: meaningful information must not depend solely on color.

---

# 21. Help

The prompt may support an interactive help action.

Conceptually:

```text
--help TEXT
```

or equivalent prompt-specific help content.

The `help` action can display instructions without submitting the prompt.

For example:

```text
? Show help
```

The exact command-line syntax can be decided during implementation.

---

# 22. No Validation Framework

Explicitly **do not add** arguments such as:

```text
--regex
--pattern
--min
--max
--min-length
--max-length
--integer
--positive
--validator
--exists
--is-file
--is-directory
--one-of
--retry
--on-invalid
```

These belong outside the primitive.

Example:

```text
while true:
    value = prompt "Port"
    if application_validation(value):
        break
    display application-specific error
```

The prompt function should simply perform the interaction again when the caller asks it to.

---

# 23. No Automatic Transformation

The utility should not silently transform user input.

Avoid built-in application-policy flags such as:

```text
--trim
--lowercase
--uppercase
--normalize
```

The prompt should return what the user entered.

If the caller wants:

```text
trim(value)
```

or:

```text
lowercase(value)
```

the caller performs that transformation.

This preserves the separation between:

> user interaction

and:

> application data processing.

---

# 24. No Special Password Type

Do not implement:

```text
--type password
```

Use:

```text
--type text --hide
```

or:

```text
--type multiline --hide
```

This keeps visibility orthogonal to interaction type.

A secret is just input whose visibility happens to be disabled.

---

# 25. No Editor Mode

Do not include an `editor` type in the initial design.

An editor-based prompt would launch `$EDITOR` and collect the resulting file contents. That is a different interaction model and is unnecessary for the core utility.

Multiline input with a caller-defined terminator is sufficient for the intended use case.

---

# 26. Important Architectural Principle

The prompt should be **composable**.

For example, a larger application can implement a wizard:

```text
Step 1:
    prompt select

Step 2:
    prompt multi-select

Step 3:
    prompt text

Step 4:
    prompt confirm
```

If the user presses Back:

```text
prompt → ACTION(back)
```

The calling application handles the navigation.

The prompt utility should not know that there are "steps."

---

# 27. Result Model

The utility should return **semantic results**, not raw keyboard events.

Conceptually, results can contain:

```text
status
action
value
```

Examples:

### Text

```text
status = success
action = submit
value = "hello"
```

### Empty

```text
status = success
action = submit
value = ""
```

when `allow-empty` is enabled.

### Select

```text
status = success
action = submit
value = "prod"
```

### Multi-select

```text
status = success
action = submit
value = ["git", "docker"]
```

### Back

```text
status = success
action = back
```

### Cancel

```text
status = cancelled
```

The exact Bash representation of these results needs to be designed carefully during implementation, but the semantic distinction should exist in the specification.

---

# 28. Exit Status

The function should have a predictable exit-status contract.

At minimum, distinguish:

```text
successful interaction
cancelled
EOF/input unavailable
internal prompt error
```

A `confirm` returning `false` must **not** be considered a failed prompt.

For example:

```text
confirm → false
```

means:

> The user successfully answered "no."

It should not mean:

> The prompt failed.

---

# 29. Design Rules

The implementation should follow these principles:

1. **One general-purpose function.**
2. **Interaction-oriented, not validation-oriented.**
3. **No domain knowledge.**
4. **No automatic data transformation.**
5. **`allow-empty` is the only acceptance-policy concept built into the prompt.**
6. **Visibility is orthogonal to prompt type.**
7. **`--hide` replaces a special password mode.**
8. **`--mask` provides an alternative hidden-input presentation.**
9. **Multiline uses an explicit caller-defined terminator.**
10. **`--include-end` controls whether the terminator is returned.**
11. **Selection options have separate value and display label.**
12. **Multi-select uses Space to toggle and Enter to submit by default.**
13. **Actions are semantic, not raw key presses.**
14. **Actions can be rebound with a generic binding mechanism.**
15. **Back/Proceed/etc. are handled by the caller, not by the prompt utility.**
16. **Numbered options are supported.**
17. **Presentation and keyboard behavior belong to the prompt.**
18. **Validation, business logic, and workflow belong to the caller.**

---

# 30. Conceptual Final Interface

The core interface should therefore be roughly:

```text
prompt
    --type TYPE
    --message MESSAGE

    --default VALUE
    --allow-empty

    --hide
    --mask CHARACTER

    --end STRING
    --include-end

    --options OPTIONS
    --selected VALUES

    --bind ACTION=KEY

    --description TEXT
    --placeholder TEXT
    --prefix TEXT
    --suffix TEXT
    --footer TEXT

    --plain
    --no-color
```

Not every option applies to every type.

The implementation should reject nonsensical combinations rather than silently doing something surprising.

---

# 31. Core Mental Model

The entire utility can be understood as:

```text
                ┌─────────────────────┐
                │       PROMPT        │
                ├─────────────────────┤
                │ Type                │
                │ Presentation        │
                │ Default             │
                │ Visibility          │
                │ Options             │
                │ Key bindings        │
                │ Multiline behavior  │
                └──────────┬──────────┘
                           │
                     user interaction
                           │
                           ▼
                ┌─────────────────────┐
                │       RESULT        │
                ├─────────────────────┤
                │ value               │
                │ action              │
                │ status              │
                └──────────┬──────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │   CALLING SCRIPT    │
                ├─────────────────────┤
                │ validation          │
                │ transformation      │
                │ business logic      │
                │ workflow/navigation │
                └─────────────────────┘
```

The prompt utility should be **excellent at the box above the line and deliberately ignorant of the box below it**.
