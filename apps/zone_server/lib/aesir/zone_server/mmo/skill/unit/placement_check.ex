defmodule Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheck do
  @moduledoc """
  Whether a ground skill may place its unit, checked when the cast ends.

  Three refusals, in this order, all reported as one plain skill failure:

    - **Reiteration** (`no_reiteration`): a unit already stands within the
      skill's area. The area reaches the unit Layout plus, for a player caster,
      the unit Range, around the target cell. Which units count depends on the
      skill: Safety Wall and Pneuma block each other (Pneuma is also blocked by
      Land Protector), Warp Portal and the Hunter traps are blocked by the same
      skill, any trap, Venom Dust and Poison Mist, and every other skill only by
      itself.
      Anyone's unit counts.
    - **Foot set** (`no_footset`): a character stands within the unit Layout
      plus Range. Only checked when the check is made as a player: a player is
      blocked by any player, monster or homunculus, dead ones only for Warp
      Portal, and Demonstration ignores the Emperium.
    - **Active instances** (`active_instance`): the caster already holds that
      many groups of the skill. Only players and homunculi are limited.

  `as` is the unit kind the check is made as. A cast completing checks as its
  own caster; the cast start of Fire Wall and the equipment procs check as a
  player.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @emperium 1288
  @barriers [:mg_safetywall, :al_pneuma]
  @trap_blocked [
    :al_warp,
    :ht_skidtrap,
    :ht_landmine,
    :ht_anklesnare,
    :ht_shockwave,
    :ht_sandman,
    :ht_flasher,
    :ht_freezingtrap,
    :ht_blastmine,
    :ht_claymoretrap
  ]
  @character_types [:player, :mob, :homunculus]
  @limited_types [:player, :homunculus]

  @typedoc "The caster placing the unit."
  @type caster :: {atom(), integer()}

  @doc """
  Checks the placement of `definition` on `cell` of `map_name` by `caster`,
  made as unit kind `as`.
  """
  @spec check(Definition.t(), caster(), String.t(), Group.cell(), atom()) ::
          :ok | {:error, :unit_placement_refused}
  def check(%Definition{} = definition, {caster_type, caster_id}, map_name, cell, as) do
    cond do
      reiteration_blocked?(definition, caster_type, map_name, cell) ->
        {:error, :unit_placement_refused}

      footset_blocked?(definition, caster_type, map_name, cell, as) ->
        {:error, :unit_placement_refused}

      instance_limit_reached?(definition, {caster_type, caster_id}, as) ->
        {:error, :unit_placement_refused}

      true ->
        :ok
    end
  end

  @doc """
  Whether a unit of `definition` cast by a `caster_type` caster on `cell`
  reiterates one already placed (always false without `no_reiteration`).
  """
  @spec reiteration_blocked?(Definition.t(), atom(), String.t(), Group.cell()) :: boolean()
  def reiteration_blocked?(%Definition{no_reiteration: false}, _caster_type, _map, _cell),
    do: false

  def reiteration_blocked?(%Definition{} = definition, caster_type, map_name, {x, y}) do
    range =
      if(caster_type == :player, do: definition.unit_range, else: 0) + definition.unit_layout

    map_name
    |> Storage.get_visible_groups_in_range(x, y, range)
    |> Enum.any?(&reiterates?(definition.name, &1))
  end

  defp reiterates?(:al_pneuma, %Group{skill_name: :sa_landprotector}), do: true
  defp reiterates?(name, %Group{skill_name: other}) when name in @barriers, do: other in @barriers

  defp reiterates?(name, %Group{skill_name: other} = group) when name in @trap_blocked,
    do: other == name or other in [:as_venomdust, :mh_poison_mist] or trap?(group)

  defp reiterates?(name, %Group{skill_name: other}), do: other == name

  defp trap?(%Group{skill_id: skill_id}) do
    case Catalog.by_id(skill_id) do
      {:ok, %Definition{is_trap: is_trap}} -> is_trap
      :error -> false
    end
  end

  defp footset_blocked?(
         %Definition{no_footset: true} = definition,
         caster_type,
         map,
         cell,
         :player
       ) do
    case footset_types(caster_type) do
      [] -> false
      types -> Enum.any?(types, &occupied?(&1, definition, map, cell))
    end
  end

  defp footset_blocked?(_definition, _caster_type, _map, _cell, _as), do: false

  defp footset_types(:player), do: @character_types
  defp footset_types(:mob), do: [:mob]
  defp footset_types(_caster_type), do: []

  defp occupied?(unit_type, definition, map_name, {x, y}) do
    range = definition.unit_range + definition.unit_layout

    unit_type
    |> SpatialIndex.get_units_in_area(map_name, x - range, y - range, x + range, y + range)
    |> Enum.any?(&counts_for_footset?(unit_type, &1, definition.name))
  end

  defp counts_for_footset?(unit_type, unit_id, skill_name) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} ->
        (skill_name == :al_warp or Unit.living?(state)) and
          not emperium_exempt?(skill_name, state)

      {:error, :not_found} ->
        false
    end
  end

  defp emperium_exempt?(:am_demonstration, %MobState{mob_id: @emperium}), do: true
  defp emperium_exempt?(_skill_name, _state), do: false

  defp instance_limit_reached?(%Definition{active_instance: 0}, _caster, _as), do: false

  defp instance_limit_reached?(definition, {caster_type, caster_id}, as)
       when as in @limited_types do
    definition.name
    |> Storage.get_groups_by_skill_and_caster(caster_type, caster_id)
    |> length() >= definition.active_instance
  end

  defp instance_limit_reached?(_definition, _caster, _as), do: false
end
