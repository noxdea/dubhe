# Reader-mode HTML elements

The v1 plain renderer handles `h1`–`h6`, `p`, `br`, `hr`, `ul`, `ol`, `li`,
`blockquote`, `pre`, `code`, `table`, `tr`, `td`, `th`, `img`, `a`, `em`,
`strong`, `del`, `mark`, `sub`, `sup`, `figure`, and `figcaption`.

Unknown elements contribute their children. `script`, `style`, `iframe`,
`object`, `embed`, and `form` contribute nothing. Author `style` and `class`
attributes are never used for layout or typography.
