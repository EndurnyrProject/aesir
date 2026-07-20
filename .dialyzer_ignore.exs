# Dialyzer warnings that are false positives or unavoidable tooling limitations.
# Shared by the umbrella root and every child app (their mix.exs point here).
# Each entry is {relative_file, warning_type}; keep this list minimal and
# justified — prefer fixing the code over silencing real findings.
[
  # Ecto.Multi is built with opaque internals; chaining `Multi.new() |> Multi.run/3`
  # makes dialyzer flag the accumulator as carrying opaque subterms. This is a known
  # dialyzer limitation with Ecto.Multi, not a real defect.
  {"lib/aesir/char_server/characters.ex", :call_without_opaque},
  {"lib/aesir/zone_server/party/manager.ex", :call_without_opaque},
  {"lib/aesir/zone_server/guild/manager.ex", :call_without_opaque},

  # MapSet is an opaque type; the A* closed-set is threaded through MapSet.put/2 and
  # the recursive loop, which dialyzer reports as opaque-term violations even though
  # the value is always a proper MapSet.
  {"lib/aesir/zone_server/pathfinding.ex", :call_without_opaque},
  {"lib/aesir/zone_server/pathfinding.ex", :call_with_opaque},

  # The NPC interaction task intentionally never returns: it runs the script and
  # ends with `exit(:normal)` so the session's monitor clears the dialog lock. The
  # spawned fun is correctly no_return by design.
  {"lib/aesir/zone_server/script/interaction.ex", :no_return},

  # CompiledItemScripts is generated at runtime by ScriptCompiler.compile_all!/1, so
  # it does not exist at compile/analysis time. The call is guarded with
  # @compile {:no_warn_undefined, CompiledItemScripts}, which dialyzer does not honor.
  {"lib/aesir/zone_server/unit/player/handlers/item_handler.ex", :unknown_function},
  {"lib/aesir/zone_server/script/dsl.ex", :unknown_function}
]
