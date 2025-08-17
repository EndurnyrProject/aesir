[
  import_deps: [:ecto, :ecto_sql],
  plugins: [Recode.FormatterPlugin],
  inputs: ["mix.exs", "config/*.exs", "priv/db/**/*.exs", "priv/db/*.exs"],
  subdirectories: ["apps/*"]
]
