defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gospel do
  @moduledoc """
  Battle Chant caster lock (SC_GOSPEL, caster side).

  While chanting, the Paladin cannot move or cast any skill other than Gospel
  itself (recasting ends the chant), and every 10 seconds pays 30 HP and 20 SP
  at levels 1-5 or 45 HP and 35 SP at levels 6-10. When the upkeep cannot be
  paid the chant ends. `val2` holds the Gospel field's group id: ending the
  status tears the field down, and the field ending removes this status, so
  either side may finish first. The chant also ends on map change, on Silence
  (declared on `sc_silence`), and on death.

  The reference keeps the caster lock and the enemy slow on one status id with
  a discriminator; Aesir's status properties are static per definition, so the
  enemy half lives on `sc_gospel_slow`. Identical in both game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gospel,
    no_dispel: true,
    no_save: true,
    bypass_resistance: true,
    remove_on_map_change: true,
    target_types: [:player],
    properties: [:prevents_movement, :prevents_skills],
    allow_skills: [369],
    tick_interval: 10_000,
    icon: :gospel

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick({:player, id}, %StatusEntry{val1: level} = entry, _context) do
    with {:ok, {_module, _state, pid}} when is_pid(pid) <- UnitRegistry.get_unit(:player, id),
         :ok <- PlayerSession.try_consume_vitals(pid, upkeep(level)) do
      {:ok, entry}
    else
      _unpaid -> :remove
    end
  end

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire(_target, %StatusEntry{val2: group_id}, _context) when is_integer(group_id),
    do: Unit.destroy_async(group_id)

  def on_expire(_target, _entry, _context), do: :ok

  defp upkeep(level) when level > 5, do: [hp: 45, sp: 35]
  defp upkeep(_level), do: [hp: 30, sp: 20]
end
