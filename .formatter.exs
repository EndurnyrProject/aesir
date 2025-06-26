# Used by "mix format"
[
  import_deps: [:mimic],
  plugins: [Recode.FormatterPlugin],
  inputs: ["mix.exs", "config/*.exs"],
  subdirectories: ["apps/*"]
]
