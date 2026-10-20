defmodule Aesir.ZoneServer.Unit.Mob.HitSkillEvents do
  @moduledoc """
  The monster skill events a landed battle hit fires.

  The port of the reference's `battle_damage` tail, run inside the monster's
  own process, in this order:

    * an attack-type event carrying the hit's damage, when the hit took HP:
      the close-attack event for a short-range hit, the long-range event for a
      long-range hit that is not magic (magic falls through), and the
      any-damage event otherwise;
    * the skill-used event of the skill that produced the hit, whatever the
      hit took (its damage is what the ground-attacked rows read).

  Only a landed hit counts, the source must not be the monster itself, and a
  passive HP loss or a status tick is not a battle hit at all - the reference
  never routes those through `battle_damage`.
  """

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc """
  Runs the hit's events on `state`, which must be alive, and returns it with
  whatever the monster's reactions changed (a started cast included).
  """
  @spec run(MobState.t(), integer(), tuple(), map(), integer()) :: MobState.t()
  def run(%MobState{} = state, damage, attacker_ref, metadata, tick) do
    if landed?(state, damage, attacker_ref, metadata) do
      state
      |> attack_event(damage, attacker_ref, metadata, tick)
      |> skill_used_event(damage, attacker_ref, metadata, tick)
    else
      state
    end
  end

  defp attack_event(state, damage, attacker_ref, metadata, tick) when damage > 0,
    do: event(state, attacker_ref, {:attacked, attack_kind(metadata), damage}, tick)

  defp attack_event(state, _damage, _attacker_ref, _metadata, _tick), do: state

  defp skill_used_event(state, damage, attacker_ref, metadata, tick) do
    case Map.get(metadata, :skill_id) do
      skill_id when is_integer(skill_id) and skill_id > 0 ->
        event(state, attacker_ref, {:skillused, skill_id, damage}, tick)

      _no_skill ->
        state
    end
  end

  defp event(state, attacker_ref, event, tick) do
    {:noreply, updated} = AiHandler.handle_skill_event(state, attacker_ref, event, tick)
    updated
  end

  # A short-range hit is the close-attack event whatever its type; a magic hit
  # is never the long-range event; anything without a range flag, and every
  # other type, is the any-damage event.
  defp attack_kind(%{is_short: true}), do: :closed
  defp attack_kind(%{dmg_type: :magic}), do: :other
  defp attack_kind(%{is_short: false}), do: :long
  defp attack_kind(_metadata), do: :other

  defp landed?(_state, _damage, _attacker_ref, %{passive?: true}), do: false
  defp landed?(_state, _damage, _attacker_ref, %{status_tick?: true}), do: false

  defp landed?(%MobState{instance_id: id}, damage, attacker_ref, metadata) do
    attacker_ref != {:mob, id} and DamageShared.hit_class(metadata, damage, true) == :hit
  end
end
