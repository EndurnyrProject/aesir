defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica do
  @moduledoc """
  Pre-renewal Basilica occupant (SC_BASILICA in pre-renewal). `val1` is the
  skill level.

  Granted by the Basilica sanctuary field to every unit standing in it except
  its caster, bosses included. As the last blocker, after Kyrie Eleison and
  Safety Wall, it blocks every attack still carrying damage unless the attacker
  is status-immune (a boss-class monster or one with the status-immune mode).
  The holder cannot attack or cast; it may still walk out. The field removes the status when the holder leaves, and the
  holder's own one-second tick drops it if the holder is no longer on any
  Basilica cell (a teleport or relocation emits no leave event). It ends on map
  change and is never saved or dispelled.

  Renewal Basilica is the `sc_basilica_buff` self buff; this status is only
  granted in pre-renewal. `absorb_damage/4` is shared with the caster lock,
  `sc_basilica_caster`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_basilica,
    no_save: true,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    remove_on_map_change: true,
    bypass_boss_immunity: true,
    bypass_resistance: true,
    target_types: [:player, :mob],
    properties: [:prevents_attack, :prevents_skills],
    tick_interval: 1_000,
    icon: :basilica

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick({unit_type, unit_id}, entry, _context) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         true <- Storage.basilica?(map_name, x, y) do
      {:ok, entry}
    else
      _off_sanctuary -> :remove
    end
  end

  @doc """
  Blocks the hit unless its source is status-immune. A hit with no known source
  is blocked: traps and ground fields belong to ordinary owners.
  """
  @impl true
  def absorb_damage(_target, instance, %{attacker: {unit_type, unit_id}} = hit_info, _context) do
    if status_immune?(unit_type, unit_id),
      do: {:ok, hit_info.damage, instance},
      else: {:ok, 0, instance}
  end

  def absorb_damage(_target, instance, _hit_info, _context), do: {:ok, 0, instance}

  defp status_immune?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {MobState, %MobState{mob_data: %{modes: modes}}, _pid}} ->
        Enum.any?(modes, &(&1 in [:boss, :status_immune]))

      _not_a_mob ->
        false
    end
  end
end
