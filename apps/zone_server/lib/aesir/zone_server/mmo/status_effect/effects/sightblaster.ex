defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sightblaster do
  @moduledoc """
  Sight Blaster (SC_SIGHTBLASTER).

  Starting 20 ms after application, each tick strikes every eligible enemy in
  the surrounding 3x3 square in map block order. A damaging non-trap contact
  consumes the status only after the whole sweep. Misses, reflected spells and
  suppressed hits leave it armed. Movement alone never triggers a strike.

  Trap strikes do not consume the status. An armed caster is immune to trap
  triggers until a skill-unit contact temporarily lifts that immunity; the
  next tick restores it. Renewal strikes for 600% Fire MATK, classic for 100%,
  with three cells of knockback on a damaging hit.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sightblaster,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    target_types: [:player],
    duration: 900_000,
    tick_interval: 20,
    no_save: true,
    icon: :wz_sightblaster,
    option: :sight

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @skill_id 1006
  @knockback 3

  @impl true
  def on_apply(_target, instance, _context),
    do: {:ok, set_immunity(instance, true)}

  @impl true
  def on_tick({:player, caster_id} = caster_ref, instance, _context) do
    current = publish(caster_id, instance, set_immunity(instance, true))

    with {:ok, {_module, caster, _pid}} <- UnitRegistry.get_unit(:player, caster_id),
         {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(:player, caster_id) do
      {current, consumed?} =
        map_name
        |> SpatialIndex.get_all_units_in_range(x, y, 1)
        |> Enum.filter(fn {type, _id} = ref ->
          type in [:player, :mob, :homunculus, :skill_unit] and ref != caster_ref
        end)
        |> Enum.reduce({current, false}, fn contact, {current, consumed?} ->
          {updated, consumes?} = trigger_contact(caster, current, contact, {x, y})
          {updated, consumed? or consumes?}
        end)

      if consumed?, do: :remove, else: {:ok, current}
    else
      _unavailable -> {:ok, current}
    end
  end

  defp trigger_contact(caster, instance, {type, _id} = contact, {x, y}) do
    if eligible?(caster.character_id, contact) do
      trap? = trap?(contact)
      consumes? = strike(caster, instance, contact, x, y) and not trap?

      updated =
        if consumes? or type == :skill_unit,
          do: publish(caster.character_id, instance, set_immunity(instance, false)),
          else: instance

      {updated, consumes?}
    else
      {instance, false}
    end
  end

  defp strike(caster, instance, {type, id}, x, y) do
    case Combat.execute_magic_attack(caster, id,
           skill_id: @skill_id,
           skill_level: instance.val1,
           skill_ratio: skill_ratio(),
           element: :fire,
           report_hit: true
         ) do
      {:ok, %{damage: damage}} when damage > 0 ->
        _ = Combat.knockback(type, id, x, y, @knockback)
        true

      _no_hit ->
        false
    end
  end

  defp eligible?(caster_id, {type, id} = contact) do
    with true <- living_contact?(contact),
         {:ok, definition} <- Catalog.by_id(@skill_id) do
      Targeting.validate_skill_use(
        %{unit_type: :player, unit_id: caster_id},
        %{unit_type: type, unit_id: id},
        definition,
        :splash
      ) == :ok
    else
      _unavailable -> false
    end
  end

  defp trap?({:skill_unit, cell_id}) do
    with %Cell{group_id: group_id} <- Storage.get_cell(cell_id),
         %Group{skill_id: skill_id} <- Storage.get(group_id),
         {:ok, definition} <- Catalog.by_id(skill_id) do
      definition.is_trap
    else
      _unavailable -> false
    end
  end

  defp trap?(_contact), do: false

  defp set_immunity(instance, enabled?),
    do: %{instance | state: Map.put(instance.state || %{}, :trap_immunity, enabled?)}

  defp publish(_caster_id, instance, instance), do: instance

  defp publish(caster_id, previous, current) do
    StatusStorage.replace_status_if_current(
      :player,
      caster_id,
      :sc_sightblaster,
      previous,
      current
    )

    current
  end

  defp living_contact?({:player, player_id}) do
    case UnitRegistry.get_unit(:player, player_id) do
      {:ok, {_module, player, _pid}} -> Unit.living?(player)
      {:error, :not_found} -> false
    end
  end

  defp living_contact?(_contact), do: true

  defp skill_ratio, do: if(GameMode.mode() == :renewal, do: 600, else: 100)
end
