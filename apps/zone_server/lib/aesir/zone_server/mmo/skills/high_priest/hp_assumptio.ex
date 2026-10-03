defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpAssumptio do
  @moduledoc """
  Assumptio (HP_ASSUMPTIO). Blesses an ally within 9 cells with
  `:sc_assumptio` for 20 seconds per level, for 20 to 60 SP.

  Renewal: 0.8 to 2.4 s cast plus 0.2 to 0.6 s fixed, 0.5 s after-cast delay.
  The status grants `50 * level` hard DEF and a Heal bonus on the holder.

  Pre-renewal: 1 to 3 s cast with no fixed part, 1.1 to 1.5 s after-cast
  delay. The status halves incoming damage (two thirds on PvP and GvG maps).

  In both modes a player cannot cast it on a monster. Monster rows cast it on
  themselves or on a friendly monster, boss allies included, through
  `mob_cast/5`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 361,
    name: :hp_assumptio,
    requires: [],
    status: :sc_assumptio,
    display_name: "Assumptio",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    splash_radius: 1,
    sp_cost: [20, 30, 40, 50, 60],
    cast_time: [
      renewal: [800, 1_200, 1_600, 2_000, 2_400],
      pre_renewal: [1_000, 1_500, 2_000, 2_500, 3_000]
    ],
    fixed_cast_time: [renewal: [200, 300, 400, 500, 600], pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(500, 5),
      pre_renewal: [1_100, 1_200, 1_300, 1_400, 1_500]
    ],
    duration: [20_000, 40_000, 60_000, 80_000, 100_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(%MobState{}, _target, _level, _definition), do: :ok
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(_caster, {:unit, target_id}, _level, _definition) do
    if UnitRegistry.unit_exists?(:player, target_id), do: :ok, else: {:error, :invalid_target}
  end

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, definition),
    do: bless(caster, {:player, Active.caster_unit_id(caster)}, level, definition)

  def cast(caster, {:unit, target_id}, level, definition),
    do: bless(caster, {:player, target_id}, level, definition)

  @impl Active
  @spec mob_cast(MobState.t(), {:unit, atom(), integer()}, pos_integer(), Definition.t(), map()) ::
          {:ok, MobState.t()} | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, unit_type, unit_id}, level, definition, _row),
    do: bless(caster, {unit_type, unit_id}, level, definition)

  # Another player's session must re-derive its cached DEF; the caster's own
  # session recalculates after the cast.
  defp bless(caster, {unit_type, unit_id}, level, definition) do
    caster_id = Active.caster_unit_id(caster)
    refresh = if unit_id == caster_id, do: [], else: [owner_refresh: :notify]

    params =
      [val1: level, caster_id: caster_id, duration: Enum.at(definition.duration, level - 1)] ++
        refresh

    case StatusInterpreter.apply_status(unit_type, unit_id, :sc_assumptio, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
