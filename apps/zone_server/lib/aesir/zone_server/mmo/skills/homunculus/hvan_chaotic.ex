defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaotic do
  @moduledoc """
  Benediction of Chaos heals Vanilmirth, its owner, or one current owner-attacker.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_014,
    name: :hvan_chaotic,
    display_name: "Benediction of Chaos",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(40, 5),
    cooldown: List.duplicate(3_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @homunculus_thresholds [20, 50, 25, 50, 34]
  @owner_thresholds [50, 60, 75, 54, 67]
  @attacker_scan_budget_ms 100
  @mob_state_timeout_ms 25

  @impl Active
  def cast(%HomunculusState{} = caster, :self, level, _definition) do
    recipient = recipient(caster, level, :rand.uniform(100))
    amount = heal_amount(caster, :rand.uniform(level))
    {:local_effects, caster, [heal_effect(caster, recipient, amount)]}
  end

  defp recipient(caster, level, roll) do
    homunculus_threshold = Enum.fetch!(@homunculus_thresholds, level - 1)
    owner_threshold = Enum.fetch!(@owner_thresholds, level - 1)

    cond do
      roll <= homunculus_threshold -> :homunculus
      roll <= owner_threshold -> :owner
      true -> random_attacker(caster)
    end
  end

  defp random_attacker(caster) do
    case eligible_attackers(caster) do
      [] -> :homunculus
      attackers -> {:mob, Enum.at(attackers, :rand.uniform(length(attackers)) - 1)}
    end
  end

  defp eligible_attackers(caster) do
    case owner_snapshot(caster.owner_character_id) do
      {:ok, owner} -> scan_attackers(owner, caster.owner_character_id)
      _unavailable -> []
    end
  end

  defp scan_attackers(owner, owner_id) do
    deadline = System.monotonic_time(:millisecond) + @attacker_scan_budget_ms

    owner.map_name
    |> SpatialIndex.get_all_units_in_range(owner.x, owner.y, 28)
    |> Enum.sort()
    |> Enum.reduce_while([], fn target_ref, attackers ->
      case eligible_attacker(target_ref, owner, owner_id, deadline) do
        {:eligible, id} -> {:cont, [id | attackers]}
        :ineligible -> {:cont, attackers}
        :expired -> {:halt, attackers}
      end
    end)
    |> Enum.reverse()
  end

  defp owner_snapshot(owner_id) do
    case UnitRegistry.get_unit(:player, owner_id) do
      {:ok, {_module, %{x: x, y: y, map_name: map_name} = owner, _pid}}
      when is_integer(x) and is_integer(y) and is_binary(map_name) ->
        {:ok, owner}

      _unavailable ->
        {:error, :owner_unavailable}
    end
  end

  defp eligible_attacker({:mob, id}, owner, owner_id, deadline) do
    with {:ok, {MobState, _snapshot, pid}} when is_pid(pid) <- UnitRegistry.get_unit(:mob, id),
         {:ok, %MobState{} = mob} <- live_mob_state(pid, deadline),
         true <- mob.instance_id == id,
         true <- Unit.living?(mob),
         true <- mob.map_name == owner.map_name,
         true <- mob.target_ref == {:player, owner_id},
         true <- max(abs(mob.x - owner.x), abs(mob.y - owner.y)) <= 14 do
      {:eligible, id}
    else
      :expired -> :expired
      _unavailable -> :ineligible
    end
  end

  defp eligible_attacker(_target_ref, _owner, _owner_id, _deadline), do: :ineligible

  defp live_mob_state(pid, deadline) do
    remaining_ms = deadline - System.monotonic_time(:millisecond)

    if remaining_ms > 0 do
      {:ok, GenServer.call(pid, :get_state, min(remaining_ms, @mob_state_timeout_ms))}
    else
      :expired
    end
  catch
    :exit, _reason ->
      if System.monotonic_time(:millisecond) >= deadline,
        do: :expired,
        else: {:error, :mob_unavailable}
  end

  defp heal_amount(caster, rank) do
    stat_term = div(div(caster.level + caster.int, 5) * 30 * rank, 10)
    stat_term + DamageShared.roll(caster.combat_stats.matk_min, caster.combat_stats.matk_max)
  end

  defp heal_effect(caster, :homunculus, amount) do
    source = {:homunculus, caster.world_gid}
    DamageApplication.local_heal_effect(source, amount, source)
  end

  defp heal_effect(caster, :owner, amount) do
    {:player, {:apply_heal, amount, {:homunculus, caster.world_gid}}}
  end

  defp heal_effect(caster, {:mob, id}, amount) do
    {:mob, {:apply_heal, id, amount, {:homunculus, caster.world_gid}}}
  end
end
