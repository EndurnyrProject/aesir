defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Dancing do
  @moduledoc """
  Pre-renewal performing lock. Renewal songs never apply this status.

  The performer cannot move or attack, may use only the listed skills, and
  pays one SP at the song's upkeep cadence. Ending the lock ends its field.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dancing,
    no_dispel: true,
    no_save: true,
    bypass_resistance: true,
    remove_on_map_change: true,
    target_types: [:player],
    properties: [:prevents_movement, :prevents_attack, :prevents_skills],
    allow_skills: [316, 324, 304],
    tick_interval: 1_000,
    icon: :bdplaying

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(_instance, _context),
    do: %{sp_regen: -100, skill_sp_regen_rate: -100}

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick(
        {:player, id},
        %StatusEntry{state: %{upkeep: upkeep, ticks: ticks}} = entry,
        _context
      ) do
    updated = %{entry | state: %{entry.state | ticks: ticks + 1}}

    if rem(ticks + 1, upkeep) == 0 do
      with {:ok, {_module, _state, pid}} when is_pid(pid) <- UnitRegistry.get_unit(:player, id),
           :ok <- PlayerSession.try_consume_sp(pid, 1) do
        {:ok, updated}
      else
        _ -> :remove
      end
    else
      {:ok, updated}
    end
  end

  @impl true
  @spec after_damage_taken(Definition.target(), StatusEntry.t(), map(), Definition.context()) ::
          :ok | :remove
  def after_damage_taken(_target, _entry, %{damage: damage}, %{target: %{max_hp: max_hp}})
      when is_integer(max_hp) and max_hp > 0 do
    if damage > div(max_hp, 4), do: :remove, else: :ok
  end

  def after_damage_taken(_target, _entry, _hit, _context), do: :ok

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire(_target, %StatusEntry{val2: group_id}, _context) when is_integer(group_id),
    do: Unit.destroy_async(group_id)

  def on_expire(_target, _entry, _context), do: :ok
end
