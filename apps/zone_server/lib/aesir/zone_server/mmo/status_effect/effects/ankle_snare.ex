defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AnkleSnare do
  @moduledoc """
  Ankle Snare (SC_ANKLESNARE).

  The finite movement lock stores the matching trap group/link pair. Status
  teardown asks the manager to release only that pair; stale peers self-heal on
  the next tick.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_anklesnare,
    no_dispel: true,
    no_save: true,
    remove_on_map_change: true,
    bypass_resistance: true,
    properties: [:debuff, :prevents_movement],
    flags: [:no_move],
    blocked_skills: [26],
    prevented_by: [:sc_anklesnare],
    immunity: [:status_immune],
    tick_interval: 1_000,
    icon: :anklesnare

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def on_expire(_target, %StatusEntry{state: %{group_id: group_id, link_id: link_id}}, _context)
      when is_integer(group_id) and is_integer(link_id) do
    Manager.release_trap_link(group_id, link_id)
    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok

  @impl true
  def on_tick(target, %StatusEntry{} = instance, _context) do
    if linked_group?(target, instance.state), do: {:ok, instance}, else: :remove
  end

  defp linked_group?(
         {target_type, target_id},
         %{group_id: group_id, link_id: link_id}
       ) do
    match?(
      %Group{
        target_type: ^target_type,
        target_id: ^target_id,
        state: %{trap: %TrapState{phase: :captured, link_id: ^link_id}}
      },
      Storage.get(group_id)
    )
  end

  defp linked_group?(_target, _state), do: false
end
