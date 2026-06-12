defmodule Aesir.ZoneServer.Mmo.MobManagement.Definition do
  @moduledoc """
  Declarative macro for defining mobs as plain Elixir modules.

  A mob module declares its static data through `use` options, validated with
  Peri at compile time. The resulting `MobDefinition` struct is built once at
  compile time and served from the module's constant pool.

  ## Example

      defmodule Aesir.ZoneServer.Mmo.MobManagement.Mobs.Poring do
        use Aesir.ZoneServer.Mmo.MobManagement.Definition,
          id: 1002,
          aegis_name: :PORING,
          name: "Poring",
          level: 1,
          hp: 55,
          atk_min: 1,
          atk_max: 1,
          stats: %{str: 6, agi: 1, vit: 1, int: 0, dex: 6, luk: 5},
          attack_range: 1,
          size: :medium,
          race: :plant,
          element: {:water, 1},
          walk_speed: 400,
          attack_delay: 1_872,
          attack_motion: 672,
          client_attack_motion: 288,
          damage_motion: 480,
          drops: [
            %{item: "Jellopy", rate: 7_000},
            %{item: "Poring_Card", rate: 20, steal_protected: true}
          ]
      end

  Drops are plain maps validated against the drop schema and built into
  `MobDrop` structs. Optional fields and their defaults: `sp: 0`,
  `base_exp: 0`, `job_exp: 0`, `def: 0`, `mdef: 0`, `skill_range: 10`,
  `chase_range: 12`, `ai_type: 0`, `modes: []`, `drops: []`.
  """

  alias Aesir.ZoneServer.Mmo.DefinitionValidation
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  @doc "Returns the fully-populated mob struct."
  @callback mob() :: MobDefinition.t()

  @doc "Returns the numeric mob id."
  @callback id() :: integer()

  @sizes [:small, :medium, :large]

  @races [
    :formless,
    :undead,
    :brute,
    :plant,
    :insect,
    :fish,
    :demon,
    :demihuman,
    :angel,
    :dragon
  ]

  @elements [
    :neutral,
    :water,
    :earth,
    :fire,
    :wind,
    :poison,
    :holy,
    :shadow,
    :ghost,
    :undead
  ]

  @modes [:aggressive, :boss, :plant, :undead, :no_move, :no_attack]

  @stats_schema %{
    str: {:required, {:integer, {:gte, 0}}},
    agi: {:required, {:integer, {:gte, 0}}},
    vit: {:required, {:integer, {:gte, 0}}},
    int: {:required, {:integer, {:gte, 0}}},
    dex: {:required, {:integer, {:gte, 0}}},
    luk: {:required, {:integer, {:gte, 0}}}
  }

  @drop_schema %{
    item: {:required, :string},
    rate: {:required, {:integer, {:range, {1, 10_000}}}},
    steal_protected: :boolean,
    random_option_group: :string
  }

  @schema %{
    id: {:required, {:integer, {:gt, 0}}},
    aegis_name: {:required, :atom},
    name: {:required, :string},
    level: {:required, {:integer, {:gt, 0}}},
    hp: {:required, {:integer, {:gt, 0}}},
    sp: {:integer, {:gte, 0}},
    base_exp: {:integer, {:gte, 0}},
    job_exp: {:integer, {:gte, 0}},
    atk_min: {:required, {:integer, {:gte, 0}}},
    atk_max: {:required, {:integer, {:gte, 0}}},
    def: {:integer, {:gte, 0}},
    mdef: {:integer, {:gte, 0}},
    stats: {:required, @stats_schema},
    attack_range: {:required, {:integer, {:gt, 0}}},
    skill_range: {:integer, {:gt, 0}},
    chase_range: {:integer, {:gt, 0}},
    size: {:required, {:enum, @sizes}},
    race: {:required, {:enum, @races}},
    element: {:required, {:tuple, [{:enum, @elements}, {:integer, {:range, {1, 4}}}]}},
    walk_speed: {:required, {:integer, {:gt, 0}}},
    attack_delay: {:required, {:integer, {:gt, 0}}},
    attack_motion: {:required, {:integer, {:gte, 0}}},
    client_attack_motion: {:required, {:integer, {:gte, 0}}},
    damage_motion: {:required, {:integer, {:gte, 0}}},
    ai_type: {:integer, {:gte, 0}},
    modes: {:list, {:enum, @modes}},
    drops: {:list, @drop_schema}
  }

  @defaults %{
    sp: 0,
    base_exp: 0,
    job_exp: 0,
    def: 0,
    mdef: 0,
    skill_range: 10,
    chase_range: 12,
    ai_type: 0,
    modes: [],
    drops: []
  }

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Aesir.ZoneServer.Mmo.MobManagement.Definition

      @mob_definition Aesir.ZoneServer.Mmo.MobManagement.Definition.build!(opts, __MODULE__)

      @impl true
      def mob, do: @mob_definition

      @impl true
      def id, do: @mob_definition.id
    end
  end

  @doc """
  Validates `use` options and builds the `MobDefinition` struct.

  Raises `ArgumentError` at compile time when the options are invalid, naming
  the offending module and fields.
  """
  @spec build!(keyword() | map(), module()) :: MobDefinition.t()
  def build!(opts, module) do
    data = Map.new(opts)

    check_nested_keys!(data, module)
    validated = DefinitionValidation.validate!(@schema, data, module, @defaults)
    check_atk_range!(validated, module)

    drops = Enum.map(validated.drops, &struct!(MobDrop, &1))
    struct!(MobDefinition, %{validated | drops: drops})
  end

  defp check_nested_keys!(data, module) do
    data |> Map.get(:drops, []) |> check_drop_keys!(module)
    data |> Map.get(:stats, %{}) |> check_stats_keys!(module)
    :ok
  end

  defp check_drop_keys!(drops, module) when is_list(drops) do
    Enum.each(drops, fn
      drop when is_map(drop) ->
        DefinitionValidation.check_unknown_keys!(@drop_schema, drop, module)

      _other ->
        :ok
    end)
  end

  defp check_drop_keys!(_drops, _module), do: :ok

  defp check_stats_keys!(stats, module) when is_map(stats) do
    DefinitionValidation.check_unknown_keys!(@stats_schema, stats, module)
  end

  defp check_stats_keys!(_stats, _module), do: :ok

  defp check_atk_range!(%{atk_min: atk_min, atk_max: atk_max}, module) do
    if atk_min > atk_max do
      raise ArgumentError,
            "invalid definition metadata in #{inspect(module)}: " <>
              "atk_min #{atk_min} is greater than atk_max #{atk_max}"
    end

    :ok
  end
end
