defmodule Aesir.ZoneServer.Unit.Mob.AttackedEvent do
  @moduledoc """
  The attacked event a landed battle hit schedules on a monster.

  A hit that connected (`:hit` class, 0 damage included for a fixed or
  reflected hit) and carries its division count (`:div`, set by every attack
  path; status ticks, passive HP loss and status-started damage carry none)
  schedules `{:ai, {:attacked, attacker_ref, norm?}}` in the mob's own session
  after the hit's walk delay. A coma hit is classified and delayed by the
  hit's own damage (`:hit_damage`), not the HP the coma took. A unit's own normal attack (`weapon_attack?:
  true`; never a splash or skill hit) on a mob
  in its attack state whose target is not the attacker, from within its attack
  range + 1, is a "norm" event.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @multihit_delay 200

  @doc """
  Schedules the attacked event for a hit of `damage` from `attacker_ref` with
  delivery metadata `metadata`; anything but a landed battle hit from a known
  attacker schedules nothing.
  """
  @spec schedule(MobState.t(), integer(), tuple() | nil, map()) :: :ok
  def schedule(
        %MobState{} = state,
        damage,
        {_type, _id} = attacker_ref,
        %{div: divisions} = metadata
      ) do
    damage =
      if Map.get(metadata, :coma?, false), do: Map.fetch!(metadata, :hit_damage), else: damage

    if landed?(metadata, damage) do
      delay = walk_delay(damage, divisions, state.mob_data.damage_motion)
      norm? = norm_attacked?(state, attacker_ref, metadata)
      Process.send_after(self(), {:ai, {:attacked, attacker_ref, norm?}}, delay)
    end

    :ok
  end

  def schedule(_state, _damage, _attacker_ref, _metadata), do: :ok

  @doc """
  The walk delay a hit gives a monster: 0 for damage below 1 or no divisions,
  else its damage motion plus 200 ms per extra division (more than 10 counts
  as 2), at least 1.
  """
  @spec walk_delay(integer(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def walk_delay(damage, _divisions, _damage_motion) when damage < 1, do: 0
  def walk_delay(_damage, 0, _damage_motion), do: 0

  def walk_delay(_damage, divisions, damage_motion) do
    divisions = if divisions > 10, do: 2, else: divisions
    max(damage_motion + @multihit_delay * (divisions - 1), 1)
  end

  defp landed?(%{passive?: true}, _damage), do: false
  defp landed?(%{status_tick?: true}, _damage), do: false
  defp landed?(metadata, damage), do: DamageShared.hit_class(metadata, damage, true) == :hit

  defp norm_attacked?(%MobState{} = state, attacker_ref, %{weapon_attack?: true}) do
    MobState.skill_state(state) == :berserk and state.target_ref != attacker_ref and
      within?(state, attacker_ref, MobState.get_attack_range(state) + 1)
  end

  defp norm_attacked?(_state, _attacker_ref, _metadata), do: false

  defp within?(state, {type, id}, range) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map_name}} when map_name == state.map_name ->
        Geometry.chebyshev_distance(x, y, state.x, state.y) <= range

      _other ->
        false
    end
  end
end
