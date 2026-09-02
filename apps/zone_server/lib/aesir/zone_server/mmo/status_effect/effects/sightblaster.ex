defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sightblaster do
  @moduledoc """
  Sight Blaster (SC_SIGHTBLASTER).

  The caster is armed until an enemy is within one cell. It checks immediately
  and on 20ms status ticks, while movement contact uses the same trigger path.
  The first successful hit deals 600% Fire magic damage, knocks the target
  back, and consumes the status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sightblaster,
    no_dispel: true,
    properties: [:buff],
    target_types: [:player],
    duration: 900_000,
    tick_interval: 20,
    no_save: true,
    icon: :wz_sightblaster,
    option: :sight

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @skill_id 1006
  @skill_ratio 600
  @knockback 3

  @impl true
  def on_apply(target, instance, _context), do: trigger_nearby(target, instance)

  @impl true
  def on_tick(target, instance, _context), do: trigger_nearby(target, instance)

  @impl true
  def on_contact({:player, caster_id}, instance, {target_type, target_id} = contact, _context) do
    if living_contact?(contact) and hostile_contact?(caster_id, contact) do
      with {:ok, {_module, caster, _pid}} <- UnitRegistry.get_unit(:player, caster_id),
           {:ok, {x, y, _map_name}} <- SpatialIndex.get_unit_position(:player, caster_id),
           {:ok, _ref} <-
             Combat.execute_magic_attack(caster, target_id,
               skill_id: @skill_id,
               skill_level: instance.val1,
               skill_ratio: @skill_ratio,
               element: :fire
             ) do
        _ = Combat.knockback(target_type, target_id, x, y, @knockback)
        :remove
      else
        {:error, _reason} -> {:ok, instance}
      end
    else
      {:ok, instance}
    end
  end

  # rAthena gates the trigger on `battle_check_target(..., BCT_ENEMY)`, so a
  # friendly ground unit (the caster's own or an ally's Ice Wall) is never a
  # target. A `CombatTarget` cell carries no caster identity, so its owning
  # group's caster relation is resolved here; mob and player contacts fall
  # through to the relation check inside `execute_magic_attack`. Under the
  # current pre-PvP relation policy only mob-owned ground units are enemies of
  # the (always player) Sight Blaster caster.
  defp hostile_contact?(caster_id, {:skill_unit, cell_id}) do
    with %Cell{group_id: group_id} <- Storage.get_cell(cell_id),
         %Group{caster_type: owner_type, caster_id: owner_id} <- Storage.get(group_id) do
      attacker = %{unit_type: :player, unit_id: caster_id, party_id: 0, guild_id: 0}
      owner = %{unit_type: owner_type, unit_id: owner_id, party_id: 0, guild_id: 0}
      Targeting.validate_enemy(attacker, owner) == :ok
    else
      _ -> false
    end
  end

  defp hostile_contact?(_caster_id, _contact), do: true

  @spec trigger_nearby({:player, integer()}, struct()) :: {:ok, struct()} | :remove
  defp trigger_nearby({:player, caster_id} = caster, instance) do
    case SpatialIndex.get_unit_position(:player, caster_id) do
      {:ok, {x, y, map_name}} ->
        trigger_contacts(caster, instance, map_name, x, y)

      {:error, _reason} ->
        {:ok, instance}
    end
  end

  @spec trigger_contacts({:player, integer()}, struct(), String.t(), integer(), integer()) ::
          {:ok, struct()} | :remove
  defp trigger_contacts(caster, instance, map_name, x, y) do
    map_name
    |> SpatialIndex.get_all_units_in_range(x, y, 1)
    |> Enum.reject(&(&1 == caster))
    |> Enum.reduce_while({:ok, instance}, &trigger_contact(caster, &1, &2))
  end

  @spec trigger_contact({:player, integer()}, {atom(), integer()}, {:ok, struct()}) ::
          {:cont, {:ok, struct()}} | {:halt, :remove}
  defp trigger_contact(caster, contact, {:ok, instance}) do
    case on_contact(caster, instance, contact, %{}) do
      :remove -> {:halt, :remove}
      {:ok, next_instance} -> {:cont, {:ok, next_instance}}
    end
  end

  defp living_contact?({:player, player_id}) do
    case UnitRegistry.get_unit(:player, player_id) do
      {:ok, {_module, player, _pid}} -> Unit.living?(player)
      {:error, :not_found} -> false
    end
  end

  defp living_contact?(_contact), do: true
end
