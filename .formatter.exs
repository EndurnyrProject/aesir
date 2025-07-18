[
  import_deps: [:mimic, :ecto, :ecto_sql],
  plugins: [Recode.FormatterPlugin],
  inputs: ["mix.exs", "config/*.exs"],
  subdirectories: ["apps/*"]
]
