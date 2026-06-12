defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition do
  @moduledoc """
  Declarative macro for per-map mob spawn definitions.

  A spawn module declares its map and spawn entries through `use` options,
  validated with Peri at compile time. Mobs are referenced by their definition
  module; the reference is stored as data and the mob module is invoked at
  spawn time. The `Spawns` registry validates these references when it builds
  its index.

  ## Example

      defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.PrtFild01 do
        alias Aesir.ZoneServer.Mmo.MobManagement.Mobs.Poring

        use Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition,
          map: "prt_fild01",
          spawns: [
            %{mob: Poring, amount: 1, respawn_time: 10_000, area: %{x: 110, y: 203, xs: 5, ys: 5}}
          ]
      end

  Area `xs`/`ys` default to 0 (exact position); `x: 0, y: 0, xs: 0, ys: 0`
  means anywhere on the map.
  """

  alias Aesir.ZoneServer.Mmo.DefinitionValidation
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn

  @doc "Returns the map name these spawns belong to."
  @callback map_name() :: String.t()

  @doc "Returns the spawn entries for the map."
  @callback spawns() :: [MobSpawn.t()]

  @area_schema %{
    x: {:required, {:integer, {:gte, 0}}},
    y: {:required, {:integer, {:gte, 0}}},
    xs: {:integer, {:gte, 0}},
    ys: {:integer, {:gte, 0}}
  }

  @spawn_schema %{
    mob: {:required, :atom},
    amount: {:required, {:integer, {:gt, 0}}},
    respawn_time: {:required, {:integer, {:gt, 0}}},
    area: {:required, @area_schema}
  }

  @schema %{
    map: {:required, :string},
    spawns: {:required, {:list, @spawn_schema}}
  }

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition

      @spawn_definition Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition.build!(
                          opts,
                          __MODULE__
                        )

      @impl true
      def map_name, do: @spawn_definition.map

      @impl true
      def spawns, do: @spawn_definition.spawns
    end
  end

  @doc """
  Validates `use` options and builds the spawn entries.

  Raises `ArgumentError` at compile time when the options are invalid, naming
  the offending module and fields.
  """
  @spec build!(keyword() | map(), module()) :: %{map: String.t(), spawns: [MobSpawn.t()]}
  def build!(opts, module) do
    data = Map.new(opts)

    check_nested_keys!(data, module)
    validated = DefinitionValidation.validate!(@schema, data, module)

    %{map: validated.map, spawns: Enum.map(validated.spawns, &build_spawn/1)}
  end

  defp build_spawn(spawn) do
    %MobSpawn{
      mob: spawn.mob,
      amount: spawn.amount,
      respawn_time: spawn.respawn_time,
      spawn_area: struct!(MobSpawn.SpawnArea, spawn.area)
    }
  end

  defp check_nested_keys!(data, module) do
    data |> Map.get(:spawns, []) |> check_spawn_keys!(module)
    :ok
  end

  defp check_spawn_keys!(spawns, module) when is_list(spawns) do
    Enum.each(spawns, fn
      spawn when is_map(spawn) ->
        DefinitionValidation.check_unknown_keys!(@spawn_schema, spawn, module)
        spawn |> Map.get(:area, %{}) |> check_area_keys!(module)

      _other ->
        :ok
    end)
  end

  defp check_spawn_keys!(_spawns, _module), do: :ok

  defp check_area_keys!(area, module) when is_map(area) do
    DefinitionValidation.check_unknown_keys!(@area_schema, area, module)
  end

  defp check_area_keys!(_area, _module), do: :ok
end
