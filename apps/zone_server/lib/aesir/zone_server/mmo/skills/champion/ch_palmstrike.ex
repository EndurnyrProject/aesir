defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChPalmstrike do
  @moduledoc """
  Raging Palm Strike (CH_PALMSTRIKE).

  Needs Fury. The cast shows a zero-damage hit at once; the real blow lands one
  second plus one attack motion later and pushes the target 3 cells away from
  the Champion, even when it misses. If either the Champion or the target is
  hidden when it lands, only the push happens. The blow is dropped if the
  Champion died or changed map, or the target died, vanished, or left the map;
  it does not recheck range.

  Renewal: `(200 + 100*lv + STR) * BaseLv / 100` percent.
  Pre-renewal: `200 + 100*lv` percent. Both cost `2*lv` SP with a 0.3 s
  after-cast delay.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 370,
    name: :ch_palmstrike,
    display_name: "Raging Palm Strike",
    max_level: 5,
    ignore_dex: true,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    knockback: 3,
    sp_cost: [2, 4, 6, 8, 10],
    after_cast_delay: List.duplicate(300, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Fury
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @push_cells 3

  @typedoc "The target, map, and level captured for the delayed blow."
  @type impact :: %{target: {atom(), integer()}, map_name: String.t(), level: pos_integer()}

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_explosion_spirits}
  def validate(caster, _target, _level, _definition) do
    if Fury.active?(caster.character_id), do: :ok, else: {:error, :requires_explosion_spirits}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, target} <- Combat.resolve_combatant(target_id) do
      packet = PacketFactory.build_guard_packet(PlayerState.to_combatant(caster), target)
      DamageApplication.broadcast_nearby(target, packet)

      impact = %{target: {target.unit_type, target_id}, map_name: caster.map_name, level: level}
      attack_motion = div(AttackSpeed.calculate_delay_from_stats(caster.stats), 2)
      Skill.defer(__MODULE__, impact, Formulas.palm_impact_delay(attack_motion))
      {:ok, caster}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @doc "Lands one scheduled blow from the Champion's live session state."
  @impl Active
  @spec deferred(impact(), PlayerState.t()) :: :ok
  def deferred(
        %{target: {type, id}, map_name: map_name, level: level},
        %{map_name: map_name} = caster
      ) do
    with true <- Unit.living?(caster),
         {:ok, {_x, _y, ^map_name}} <- SpatialIndex.get_unit_position(type, id),
         {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(state) do
      if hidden?(:player, caster.character_id) or hidden?(type, id),
        do: push(type, id, caster),
        else: strike(caster, type, id, level)
    else
      _stale -> :ok
    end
  end

  def deferred(_impact, _caster_on_another_map), do: :ok

  defp strike(caster, type, id, level) do
    case Combat.execute_skill_attack(caster, id, attack_options(caster, level)) do
      {:ok, %{connected?: false}} -> push(type, id, caster)
      _landed_or_refused -> :ok
    end
  end

  defp attack_options(caster, level) do
    %{base_stats: %{str: str}, progression: %{base_level: base_level}} = caster.stats

    [
      skill_id: 370,
      skill_level: level,
      skill_ratio: Formulas.palm_ratio(level, str, base_level),
      skip_crit: true,
      skip_range: true,
      report_hit: true,
      base_distance: @push_cells
    ]
  end

  defp push(type, id, caster) do
    _ = Knockback.knockback(type, id, caster.x, caster.y, @push_cells)
    :ok
  end

  defp hidden?(type, id), do: StatusStorage.has_status?(type, id, :sc_hiding)
end
