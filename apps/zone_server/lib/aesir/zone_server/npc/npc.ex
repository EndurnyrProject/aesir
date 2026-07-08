defmodule Aesir.ZoneServer.Npc do
  @moduledoc """
  The single entry point for declaring a bespoke NPC.

  An NPC is one module that does `use Aesir.ZoneServer.Npc, spawn: [...]` once,
  passing its co-located placement(s), and implements the interaction entry
  point `on_talk/1`. Shaped after `use Aesir.ZoneServer.Mmo.Skill`:

    * injects `@behaviour Aesir.ZoneServer.Npc`;
    * `import`s `Aesir.ZoneServer.Script.Dsl` so dialog/economy/inventory
      primitives (`mes`/`select`/…) resolve as real functions;
    * records the raw `spawn:` placements and, through a `@before_compile`
      hook, publishes a generated `npc_id/0` and a `spawn/0` returning the
      placements normalized into `Aesir.ZoneServer.Npc.Placement` structs.

  Each spawn entry may also declare `unique_name` (defaults to `name` when
  omitted; used for `donpcevent`-style targeting) and `trigger: {xs, ys}`
  (touch-area half-extents around the cell; omit for no touch area).

  NPCs may also implement `on_event/2`, the uniform handler for rAthena-style
  event labels (`on_event("OnTouch", ctx)`, `on_event("OnTimer5000", ctx)`,
  `on_event("OnInit", ctx)`, ...). The same `@before_compile` hook derives
  `events/0` from the literal string heads of the module's `on_event/2`
  clauses, in clause order, deduped; a clause head that isn't a literal
  string fails compilation. If the module defines `events/0` itself, that
  definition is kept and derivation is skipped.

  NPC modules **depend on** the engine; nothing depends on them at compile
  time, so editing one is a one-file recompile and the registry discovers them
  at boot by scanning loaded modules (see `Aesir.ZoneServer.Npc.Registry`).

  ## Example

      defmodule Aesir.ZoneServer.Content.Npc.Morocc.TurbanThief do
        use Aesir.ZoneServer.Npc,
          spawn: [%{map: "morocc", x: 208, y: 90, dir: 6, sprite: 58, name: "Turban Thief"}]

        @impl true
        def on_talk(ctx) do
          ctx |> mes("Hello!") |> close()
        end
      end
  """

  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Script.Ctx

  @typedoc "A stable atom identifying the NPC module, derived from its module name."
  @type npc_id :: atom()

  @doc "Returns the NPC's stable id. Macro-provided."
  @callback npc_id() :: npc_id()

  @doc "Returns the NPC's co-located placements. Macro-provided."
  @callback spawn() :: [Placement.t()]

  @doc "Runs when a player talks to the NPC; the interaction entry point."
  @callback on_talk(Ctx.t()) :: any()

  @doc "Runs once at NPC initialization. Optional."
  @callback on_init(args :: any()) :: any()

  @doc """
  Runs when an rAthena-style event label fires (`OnTouch`, `OnTimerNNNN`,
  `OnInit`, ...). Optional.
  """
  @callback on_event(label :: String.t(), Ctx.t()) :: any()

  @doc """
  Returns the literal event labels handled by `on_event/2`. Macro-derived
  from the clause heads; overridable.
  """
  @callback events() :: [String.t()]

  @optional_callbacks on_init: 1, on_event: 2

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Aesir.ZoneServer.Npc
      @before_compile Aesir.ZoneServer.Npc

      import Aesir.ZoneServer.Script.Dsl

      @npc_spawn Keyword.get(opts, :spawn, [])
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    raw_spawn = Module.get_attribute(mod, :npc_spawn) || []
    placements = Macro.escape(Enum.map(raw_spawn, &to_placement!/1))
    id = derive_npc_id(mod)

    events_ast =
      unless Module.defines?(mod, {:events, 0}) do
        events = derive_events!(mod, env.file)

        quote do
          @impl Aesir.ZoneServer.Npc
          def events, do: unquote(events)
        end
      end

    quote do
      @impl Aesir.ZoneServer.Npc
      def npc_id, do: unquote(id)

      @impl Aesir.ZoneServer.Npc
      def spawn, do: unquote(placements)

      unquote(events_ast)
    end
  end

  @spec to_placement!(map()) :: Placement.t()
  defp to_placement!(entry) do
    name = Map.get(entry, :name, "")

    %Placement{
      map: Map.fetch!(entry, :map),
      x: Map.fetch!(entry, :x),
      y: Map.fetch!(entry, :y),
      dir: Map.get(entry, :dir, 0),
      sprite: Map.fetch!(entry, :sprite),
      name: name,
      unique_name: Map.get(entry, :unique_name, name),
      trigger: validate_trigger!(Map.get(entry, :trigger))
    }
  end

  @spec validate_trigger!(term()) :: {non_neg_integer(), non_neg_integer()} | nil
  defp validate_trigger!(nil), do: nil

  defp validate_trigger!({xs, ys})
       when is_integer(xs) and xs >= 0 and is_integer(ys) and ys >= 0 do
    {xs, ys}
  end

  defp validate_trigger!(other) do
    raise ArgumentError,
          "npc trigger must be a {non_neg_integer, non_neg_integer} tuple, got: #{inspect(other)}"
  end

  @spec derive_npc_id(module()) :: npc_id()
  defp derive_npc_id(mod) do
    mod
    |> Macro.underscore()
    |> String.replace("/", "_")
    |> String.to_atom()
  end

  @spec derive_events!(module(), Path.t()) :: [String.t()]
  defp derive_events!(mod, file) do
    case Module.get_definition(mod, {:on_event, 2}) do
      nil ->
        []

      {:v1, _kind, _meta, clauses} ->
        clauses
        |> Enum.sort_by(fn {meta, _args, _guards, _body} -> meta[:line] end)
        |> Enum.map(&extract_event_label!(&1, mod, file))
        |> Enum.uniq()
    end
  end

  @spec extract_event_label!(tuple(), module(), Path.t()) :: String.t()
  defp extract_event_label!({_meta, [label | _rest], _guards, _body}, _mod, _file)
       when is_binary(label) do
    label
  end

  defp extract_event_label!({meta, _args, _guards, _body}, mod, file) do
    raise CompileError,
      file: file,
      line: meta[:line],
      description: "#{inspect(mod)}.on_event/2 clause heads must be literal strings"
  end
end
