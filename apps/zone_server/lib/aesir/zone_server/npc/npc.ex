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

  @optional_callbacks on_init: 1

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

    quote do
      @impl Aesir.ZoneServer.Npc
      def npc_id, do: unquote(id)

      @impl Aesir.ZoneServer.Npc
      def spawn, do: unquote(placements)
    end
  end

  @spec to_placement!(map()) :: Placement.t()
  defp to_placement!(entry) do
    %Placement{
      map: Map.fetch!(entry, :map),
      x: Map.fetch!(entry, :x),
      y: Map.fetch!(entry, :y),
      dir: Map.get(entry, :dir, 0),
      sprite: Map.fetch!(entry, :sprite),
      name: Map.get(entry, :name, "")
    }
  end

  @spec derive_npc_id(module()) :: npc_id()
  defp derive_npc_id(mod) do
    mod
    |> Macro.underscore()
    |> String.replace("/", "_")
    |> String.to_atom()
  end
end
