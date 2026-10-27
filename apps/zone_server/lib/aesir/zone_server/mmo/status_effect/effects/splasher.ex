defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Splasher do
  @moduledoc """
  Target-owned Venom Splasher countdown (SC_SPLASHER). Explodes into a 2-cell
  poison weapon splash from the arming caster and poisons everything hit.

  `val1` is the skill level and `val4` the countdown. The first step runs one
  second after the status starts, then one every half second, each taking 500 ms
  off `val4`; the step that brings it to zero ends the status and explodes, so
  the explosion lands half a second after the countdown. The steps are its
  only timer: it starts with no expiry of its own. The status is saved with
  its countdown and source, and a restored one resumes the same steps. Only
  that last step explodes, and only when its source, alive or dead, is still
  in the world on the target's map; any other ending is inert.

  Renewal: 400% plus 100% per level, poison 18 s. Pre-renewal: 500% plus 50% per
  level, poison 60 s. Both add 20% per Poison React level a player source has
  when the countdown ends.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_splasher,
    no_dispel: false,
    no_clear_buff: false,
    tick_interval: 500,
    bypass_resistance: true,
    properties: [:debuff],
    immunity: [:status_immune],
    icon: :splasher

  @splasher_skill_id 141

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @poison_react_skill_id 139

  @impl true
  def on_tick(_target, %StatusEntry{val4: countdown} = instance, _context) when countdown > 500,
    do: {:ok, %{instance | val4: countdown - 500}}

  def on_tick({target_type, target_id} = target, instance, _context) do
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

  @impl true
  def on_expire(_target, _instance, _context), do: :ok

  defp explode({target_type, _target_id} = target, instance) do
    source_type = instance.source_type

    with {:ok, _pid, source, ^source_type} <-
           TargetResolver.resolve(source_type, instance.source_id),
         {:ok, ^target_type, {x, y, map_name}} <- TargetResolver.resolve_target_position(target),
         true <- source.map_name == map_name do
      source
      |> Combat.execute_forced_no_card_splash({x, y}, 2,
        skill_id: 141,
        skill_level: instance.val1,
        skill_ratio: damage_ratio(source, instance.val1),
        typed_results: true,
        delivery: {:splash, target}
      )
      |> Enum.each(&apply_poison(&1, instance))

      SpecialEffect.play(target, :splasher)
    else
      _missing_or_moved -> :ok
    end
  end

  defp damage_ratio(%PlayerState{stats: stats}, level),
    do: base_ratio(level) + 20 * PlayerStats.skill_level(stats, @poison_react_skill_id)

  defp damage_ratio(_source, level), do: base_ratio(level)

  @doc "Renewal explodes at 400% plus 100% per level; pre-renewal at 500% plus 50% per level."
  @spec base_ratio(pos_integer()) :: pos_integer()
  def base_ratio(level) do
    case GameMode.mode() do
      :renewal -> 400 + 100 * level
      :pre_renewal -> 500 + 50 * level
    end
  end

  @doc "The poison left by the explosion lasts 18 s in renewal and 60 s in pre-renewal."
  @spec poison_duration() :: pos_integer()
  def poison_duration do
    {:ok, definition} = Catalog.by_id(@splasher_skill_id)
    hd(definition.duration)
  end

  defp apply_poison({unit_type, unit_id}, instance) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_poison,
      duration: poison_duration(),
      caster_id: instance.source_id,
      source_type: instance.source_type
    )

    :ok
  end
end
