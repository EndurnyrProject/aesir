defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzFrostnova do
  @moduledoc """
  Frost Nova (WZ_FROSTNOVA). Caster-centered Water magic splash with Freeze.

  It never strikes a unit standing on the caster's own cell or on a Land
  Protector cell. Each hit that deals damage to a target that survives it tries
  to freeze for 1.5 s per level: a player source has a 33% plus 5% per level
  chance, any other source 35% plus 3% per level. A reflected hit freezes the
  caster, with the reflector as the source.

  Renewal: 100% plus 10% per level MATK over a 3-cell radius with a short cast
  and a 0.2 s delay. Pre-renewal: two thirds of that ratio over a 2-cell radius,
  a 4 to 6 s variable cast, and a 1 s delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 88,
    name: :wz_frostnova,
    requires: [],
    display_name: "Frost Nova",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :water,
    hit_count: 1,
    splash_radius: [renewal: 3, pre_renewal: 2],
    cast_time: [
      renewal: [640, 640, 576, 576, 512, 512, 448, 448, 384, 384],
      pre_renewal: [6000, 6000, 5500, 5500, 5000, 5000, 4500, 4500, 4000, 4000]
    ],
    fixed_cast_time: [renewal: [160, 160, 144, 144, 128, 128, 112, 112, 96, 96], pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(200, 10), pre_renewal: List.duplicate(1000, 10)],
    duration: [1_500, 3_000, 4_500, 6_000, 7_500, 9_000, 10_500, 12_000, 13_500, 15_000],
    sp_cost: [45, 43, 41, 39, 37, 35, 33, 31, 29, 27],
    damage_splash: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active

  @doc "Renewal deals 100% plus 10% per level; classic two thirds of that."
  @spec skill_ratio(pos_integer()) :: pos_integer()
  def skill_ratio(level) do
    case GameMode.mode() do
      :renewal -> 100 + 10 * level
      :pre_renewal -> div((100 + 10 * level) * 2, 3)
    end
  end

  @impl Active
  def cast(caster, {:unit, caster_id}, level, definition) do
    if Caster.for(caster).id(caster) == caster_id,
      do: cast(caster, :self, level, definition),
      else: {:error, :invalid_target}
  end

  def cast(caster, :self, level, definition) do
    cast(caster, :self, level, definition, &Resistance.roll_rate/1)
  end

  @doc false
  @spec cast(map(), :self, pos_integer(), struct(), (number() -> boolean())) :: {:ok, map()}
  def cast(%{x: x, y: y} = caster, :self, level, definition, resistance_roll) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level),
      element: definition.element,
      split: false,
      line_of_sight: true,
      delivery: {:area, nil},
      target_filter: &reachable_cell?(&1, {x, y}),
      additional_effect: &freeze(&1, &2, level, definition, resistance_roll)
    ]

    _ = Combat.execute_magic_splash(caster, {x, y}, definition.splash_radius, opts)
    {:ok, caster}
  end

  defp reachable_cell?({unit_type, unit_id}, caster_cell) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} ->
        {x, y} != caster_cell and not Storage.land_protected?(map_name, x, y)

      _unknown ->
        false
    end
  end

  @doc "A player source freezes with 33% plus 5% per level; any other with 35% plus 3%."
  @spec freeze_chance(atom(), pos_integer()) :: pos_integer()
  def freeze_chance(:player, level), do: 33 + 5 * level
  def freeze_chance(_unit_type, level), do: 35 + 3 * level

  defp freeze(source, {unit_type, target_id}, level, definition, resistance_roll) do
    StatusInterpreter.apply_status(unit_type, target_id, :sc_freeze,
      val1: level,
      duration: Enum.at(definition.duration, level - 1),
      success_rate: freeze_chance(source.unit_type, level),
      resistance_roll: resistance_roll,
      caster_id: source.unit_id,
      source_type: source.unit_type
    )
  end
end
