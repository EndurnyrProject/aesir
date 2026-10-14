defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Tick do
  @moduledoc """
  One Battle Chant strike on one unit standing on the field (rAthena
  `skill_unit_onplace_timer`'s UNT_GOSPEL case).

  The unit rolls `50 + 5 * level` percent; on success a member of the caster's
  party (the caster's own homunculus included, a party member's homunculus
  too) receives a random blessing and an enemy of the caster a random
  affliction. Everyone else is left alone. On a PvP map with the no-party flag
  nobody is a party member.

  Runs inside `Skill.Unit.Manager`, where resolving the caster is safe. The
  group's `state.rng` may carry an injected roll for tests.
  """

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Rolls and applies this strike's effect to `target`."
  @spec strike(Group.t(), Ref.t()) :: :ok
  def strike(%Group{caster_type: caster_type, caster_id: caster_id, level: level} = group, target) do
    with {:ok, caster} <- Combat.resolve_combatant(caster_type, caster_id),
         {:ok, {_module, caster_state, _pid}} <- UnitRegistry.get_unit(caster_type, caster_id),
         true <- roll(group) <= 50 + 5 * level,
         {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(elem(target, 0), elem(target, 1)),
         true <- Unit.living?(state) do
      affect(group, caster, caster_state, target, state)
    else
      _skip -> :ok
    end
  end

  defp affect(group, caster, caster_state, target, state) do
    cond do
      party_member?(caster_state, target, state) ->
        Effects.bless(group, target)

      Targeting.validate_enemy(caster, state) == :ok ->
        Effects.afflict(group, caster_state, target)

      true ->
        :ok
    end
  end

  # rAthena `battle_check_target(caster, target, BCT_PARTY)`: a target whose
  # master is the caster is always party; otherwise the target's (or its
  # owner's) party must be the caster's, unless the map is PvP without parties.
  defp party_member?(%{character_id: caster_id} = caster_state, target, state) do
    cond do
      owner(target, state) == caster_id -> true
      no_party_map?(caster_state.map_name) -> false
      true -> caster_state.party_id > 0 and party_id(target, state) == caster_state.party_id
    end
  end

  defp owner({:homunculus, _id}, %{owner_character_id: owner_id}), do: owner_id
  defp owner(_target, _state), do: nil

  defp party_id({:player, _id}, state), do: state.party_id

  defp party_id({:homunculus, _id}, %{owner_character_id: owner_id}) do
    case UnitRegistry.get_unit(:player, owner_id) do
      {:ok, {_module, owner_state, _pid}} -> owner_state.party_id
      _gone -> 0
    end
  end

  defp party_id(_target, _state), do: 0

  defp no_party_map?(map_name),
    do: MapFlags.get(map_name, :pvp) and MapFlags.get(map_name, :pvp_noparty)

  defp roll(%Group{state: %{rng: rng}}) when is_function(rng, 1), do: rng.(100)
  defp roll(_group), do: :rand.uniform(100)
end
