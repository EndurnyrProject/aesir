defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Splasher do
  @moduledoc """
  Target-owned Venom Splasher countdown.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_splasher,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    bypass_resistance: true,
    properties: [:debuff],
    immunity: [:status_immune],
    icon: :splasher

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @impl true
  def on_tick(_target, %StatusEntry{state: %{remaining_ms: remaining_ms}} = instance, _context)
      when remaining_ms > 500 do
    {:ok, %{instance | state: %{instance.state | remaining_ms: remaining_ms - 500}}}
  end

  def on_tick(
        {target_type, target_id} = target,
        %StatusEntry{state: %{remaining_ms: 500}} = instance,
        _context
      ) do
    if StatusInterpreter.expire_status_if_current(
         target_type,
         target_id,
         :sc_splasher,
         instance
       ) do
      explode(target, instance)
    end

    :remove
  end

  def on_tick(_target, _instance, _context), do: :remove

  @impl true
  def on_expire(_target, _instance, _context), do: :ok

  defp explode({target_type, _target_id} = target, instance) do
    source_type = instance.source_type

    with {:ok, _pid, source, ^source_type} <-
           TargetResolver.resolve(source_type, instance.source_id),
         true <- Unit.living?(source),
         {:ok, ^target_type, {x, y, map_name}} <- TargetResolver.resolve_target_position(target),
         true <- source.map_name == map_name do
      source
      |> Combat.execute_forced_no_card_splash({x, y}, 2,
        skill_id: 141,
        skill_level: instance.val1,
        skill_ratio: damage_ratio(instance),
        typed_results: true
      )
      |> Enum.each(&apply_poison(&1, instance))

      SpecialEffect.play(target, :splasher)
    else
      _missing_or_moved -> :ok
    end
  end

  defp damage_ratio(%StatusEntry{val1: level, source_type: :player, state: state}),
    do: 400 + 100 * level + 20 * Map.fetch!(state, :poison_react_level)

  defp damage_ratio(%StatusEntry{val1: level}), do: 400 + 100 * level

  defp apply_poison({unit_type, unit_id}, instance) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_poison,
      duration: 18_000,
      caster_id: instance.source_id,
      source_type: instance.source_type
    )

    :ok
  end
end
