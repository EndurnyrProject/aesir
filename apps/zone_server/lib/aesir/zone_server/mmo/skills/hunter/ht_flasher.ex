defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher do
  @moduledoc """
  Flasher (HT_FLASHER), a trap that Blinds the first enemy within one cell.

  A plant boss never sets it off. Renewal: blinds for 18 s, costs two traps.
  Pre-renewal: blinds for 30 s, costs one trap. Both last 150 s down to 30 s by
  level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 120,
    name: :ht_flasher,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    is_trap: true,
    requires: [],
    display_name: "Flasher",
    max_level: 5,
    target_type: :ground,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [150_000, 120_000, 90_000, 60_000, 30_000],
    sp_cost: [12, 12, 12, 12, 12],
    item_cost: [renewal: [%{id: 1065, amount: 2}], pre_renewal: [%{id: 1065, amount: 1}]],
    damage_splash: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, %{dex: 0, int: 0, base_level: 0}, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1,
       visibility: Trap.visibility(:ht_flasher)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs), do: Trap.unit_targets(group, refs)

  # A plant boss does not set it off.
  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, {type, id} = target, now) do
    with true <- Trap.armed?(group),
         {:ok, caster} <- Trap.resolve_caster(group),
         false <- plant_boss?(target) do
      OnHitEffects.direct(caster, target, BattleFlags.type_bit(:misc), group.skill_id)
      blind(group, type, id)
      {:ok, Trap.spring(group, now)}
    else
      _inert -> {:ok, group}
    end
  end

  defp blind(group, unit_type, unit_id) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_blind,
      duration: blind_duration(),
      success_rate: 100,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end

  defp blind_duration do
    case GameMode.mode() do
      :renewal -> 18_000
      :pre_renewal -> 30_000
    end
  end

  defp plant_boss?({:mob, mob_id}) do
    case UnitRegistry.get_unit(:mob, mob_id) do
      {:ok, {MobState, mob_state, _pid}} ->
        MobState.is_boss?(mob_state) and MobState.get_race(mob_state) == :plant

      _ ->
        false
    end
  end

  defp plant_boss?(_target), do: false
end
