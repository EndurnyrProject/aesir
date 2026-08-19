defmodule Aesir.ZoneServer.Mmo.Skill.Targeting do
  @moduledoc """
  Shared target relations for skills and combat.

  Existing callers may keep passing player and mob state maps. New relationship
  callers use typed combatants and unit references.

  Versus hostility is resolved in `validate_enemy/2`; a homunculus whose owner
  has vanished from the unit registry is treated as unaffiliated (party/guild
  0) for that single check.
  """

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Validates that `target` is a living enemy of `attacker`."
  @spec validate_enemy(map(), map()) :: :ok | {:error, :invalid_target | :target_dead}
  def validate_enemy(attacker, target) do
    if alive?(target) do
      attacker_combatant = relationship_combatant(attacker)
      target_combatant = relationship_combatant(target)
      versus = versus_context(target_combatant.map_name)

      if Relationship.enemy?(
           enrich_homunculus(attacker_combatant, versus),
           enrich_homunculus(target_combatant, versus),
           versus
         ),
         do: :ok,
         else: {:error, :invalid_target}
    else
      {:error, :target_dead}
    end
  end

  @doc "Returns whether two typed combatants are enemies on a PvE map."
  @spec enemy?(Combatant.t(), Combatant.t()) :: boolean()
  defdelegate enemy?(attacker, target), to: Relationship

  @doc "Returns whether a player may directly support the exact owned Homunculus."
  @spec direct_support?(Combatant.t() | map(), Combatant.t() | map()) :: boolean()
  def direct_support?(%Combatant{} = caster, %Combatant{} = target),
    do: Relationship.direct_support?(caster, target)

  def direct_support?(caster, target),
    do:
      Relationship.direct_support?(relationship_combatant(caster), relationship_combatant(target))

  @doc "Returns whether two unit snapshots share the exact social root."
  @spec exact_ally?(map(), map()) :: boolean()
  def exact_ally?(left, right) do
    left_root = left |> relationship_combatant() |> Relationship.social_root()
    right_root = right |> relationship_combatant() |> Relationship.social_root()
    Ref.equal?(left_root, right_root)
  end

  @doc "Returns whether an explicit ground selector chooses a typed unit reference."
  @spec ground_selected?(Relationship.ground_selector(), Ref.t()) :: boolean()
  defdelegate ground_selected?(selector, target_ref), to: Relationship

  @doc "Returns whether `map` is a versus map."
  @spec versus_map?(term()) :: boolean()
  def versus_map?(_map), do: false

  defp versus_context(map_name) when is_binary(map_name) do
    cond do
      MapFlags.get(map_name, :gvg) ->
        :gvg

      MapFlags.get(map_name, :pvp) ->
        {:pvp, MapFlags.get(map_name, :pvp_noparty), MapFlags.get(map_name, :pvp_noguild)}

      true ->
        :off
    end
  end

  defp versus_context(_map_name), do: :off

  defp relationship_combatant(unit) do
    attrs = %{
      unit_id: unit_id(unit),
      unit_type: unit_type(unit),
      party_id: Map.get(unit, :party_id, 0),
      guild_id: Map.get(unit, :guild_id, 0),
      map_name: Map.get(unit, :map_name)
    }

    unit
    |> relationship_roots(attrs)
    |> Combatant.new!()
  end

  defp enrich_homunculus(combatant, versus)

  defp enrich_homunculus(
         %Combatant{unit_type: :homunculus, social_root: {:player, owner_id}} = combatant,
         versus
       )
       when versus != :off do
    {party_id, guild_id} =
      case UnitRegistry.get_unit(:player, owner_id) do
        {:ok, {_module, owner_state, _pid}} ->
          {Map.get(owner_state, :party_id, 0), Map.get(owner_state, :guild_id, 0)}

        {:error, :not_found} ->
          {0, 0}
      end

    %{combatant | party_id: party_id, guild_id: guild_id}
  end

  defp enrich_homunculus(combatant, _versus), do: combatant

  defp relationship_roots(%{owner_character_id: owner_id}, attrs) do
    Map.merge(attrs, %{social_root: {:player, owner_id}, reward_root: {:player, owner_id}})
  end

  defp relationship_roots(unit, attrs) do
    case {Map.fetch(unit, :social_root), Map.fetch(unit, :reward_root)} do
      {{:ok, social_root}, {:ok, reward_root}} ->
        Map.merge(attrs, %{social_root: social_root, reward_root: reward_root})

      {:error, :error} ->
        attrs
    end
  end

  defp alive?(%{is_dead: true}), do: false
  defp alive?(%{action_state: :dead}), do: false
  defp alive?(%{hp: hp}) when hp <= 0, do: false
  defp alive?(%{stats: %{current_state: %{hp: hp}}}) when hp <= 0, do: false
  defp alive?(_target), do: true

  defp unit_type(%{unit_type: unit_type}), do: unit_type

  defp unit_type(%{owner_character_id: _owner_character_id, world_gid: _world_gid}),
    do: :homunculus

  defp unit_type(%{character_id: _character_id}), do: :player
  defp unit_type(%{instance_id: _instance_id}), do: :mob

  defp unit_id(%{unit_id: unit_id}), do: unit_id
  defp unit_id(%{owner_character_id: _owner_character_id, world_gid: world_gid}), do: world_gid
  defp unit_id(%{character_id: character_id}), do: character_id
  defp unit_id(%{instance_id: instance_id}), do: instance_id
end
