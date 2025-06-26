# Used by "mix format"
[
  import_deps: [:mimic],
  plugins: [Recode.FormatterPlugin],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
