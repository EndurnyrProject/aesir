defmodule Aesir.ZoneServer.Mmo.Skill.CastPacing do
  @moduledoc """
  What paces a caster between skill uses, written at the cast end: the
  skill's cooldown with the caster's equipment delta, the after-cast act
  delay with its reductions, and the per-cast overrides a skill may make to
  its cast-time and after-cast-delay tables.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.AfterCastDelay
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Monk and Champion combo skills: their resolved delay sizes the window they open.
  @combo_delay_skill_ids [272, 273, 371, 372]
  # How much an ordinary or item cast may shorten an act delay already armed.
  @act_delay_slack 100

  @doc "How much an ordinary or item cast may shorten an act delay already armed, in ms."
  @spec act_delay_slack() :: non_neg_integer()
  def act_delay_slack, do: @act_delay_slack

  @doc "Resolves the committed after-cast duration (`Skill.AfterCastDelay`)."
  @spec resolved_after_cast_delay(PlayerState.t() | map(), Definition.t(), pos_integer()) ::
          non_neg_integer()
  def resolved_after_cast_delay(game_state, definition, level) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil -> 0
      0 -> 0
      _base -> AfterCastDelay.resolve(game_state, definition, level)
    end
  end

  @doc """
  Arms the skill's cooldown on a player caster. The duration is the
  definition's per-level duration plus the caster's per-skill equipment
  `{:skill_cooldown, id}` delta (ms, negative shortens), floored at 0; a
  duration that collapses to 0 writes no entry, matching a zero-cooldown
  skill. The delta is read even for a skill with no base cooldown, so a bonus
  can give one to a skill that has none.
  """
  @spec put_cooldown(PlayerState.t(), integer(), Definition.t(), pos_integer(), integer()) ::
          PlayerState.t()
  def put_cooldown(game_state, skill_id, definition, level, now) do
    base = Cooldown.duration(definition, level)
    delta = equip_modifier(game_state, {:skill_cooldown, skill_id})

    case max(0, base + delta) do
      0 ->
        game_state

      duration ->
        cooldowns = Cooldown.put(game_state.skill_cooldowns, skill_id, now + duration)
        %{game_state | skill_cooldowns: cooldowns}
    end
  end

  @doc "Arms the skill's cooldown through the caster's adapter."
  @spec put_cooldown(
          Active.caster(),
          module(),
          integer(),
          Definition.t(),
          pos_integer(),
          integer()
        ) :: Active.caster()
  def put_cooldown(game_state, adapter, skill_id, definition, level, now) do
    duration =
      definition
      |> Cooldown.duration(level)
      |> Kernel.+(equip_modifier(game_state, {:skill_cooldown, skill_id}))
      |> max(0)

    expires_at = if duration == 0, do: 0, else: now + duration
    adapter.put_cooldown(game_state, skill_id, expires_at)
  end

  @doc "Lets a skill re-arm other cooldowns after its own (`rearm_cooldowns/4`)."
  @spec rearm_cooldowns(Active.caster(), module(), pos_integer(), Definition.t(), integer()) ::
          Active.caster()
  def rearm_cooldowns(game_state, module, level, definition, now) do
    if function_exported?(module, :rearm_cooldowns, 4),
      do: module.rearm_cooldowns(game_state, level, definition, now),
      else: game_state
  end

  @doc "Lets a skill scale its computed cast time for this cast (`scale_cast_time/4`)."
  @spec scale_cast_time(
          module(),
          Active.caster(),
          Active.target(),
          pos_integer(),
          non_neg_integer()
        ) ::
          non_neg_integer()
  def scale_cast_time(module, caster, target, level, time) do
    if function_exported?(module, :scale_cast_time, 4),
      do: module.scale_cast_time(caster, target, level, time),
      else: time
  end

  @doc """
  Arms a resolved after-cast act delay when the cast has one. The delay was
  reduced by delay-rate sources (Bragi `:delay_reduction`), not ASPD, then
  scaled by the caster's equipment `:delay_rate`; see `Skill.AfterCastDelay`.
  """
  @spec put_resolved_act_delay(Active.caster(), boolean(), non_neg_integer(), integer()) ::
          Active.caster()
  def put_resolved_act_delay(game_state, false, _delay, _now), do: game_state

  def put_resolved_act_delay(game_state, true, delay, now),
    do: arm_act_delay(game_state, now + delay, @act_delay_slack)

  @doc """
  Arms the skill's after-cast act delay on a player caster; other casters
  carry none. `slack` is how far the new delay may shorten one already armed.
  """
  @spec put_act_delay(
          Active.caster(),
          Definition.t(),
          pos_integer(),
          integer(),
          non_neg_integer()
        ) ::
          Active.caster()
  def put_act_delay(game_state, definition, level, now, slack \\ @act_delay_slack)

  def put_act_delay(%PlayerState{} = game_state, definition, level, now, slack) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil ->
        game_state

      0 ->
        game_state

      _base ->
        delay = resolved_after_cast_delay(game_state, definition, level)
        arm_act_delay(game_state, now + delay, slack)
    end
  end

  def put_act_delay(game_state, _definition, _level, _now, _slack), do: game_state

  # A new act delay never ends before the one already armed (0 is none),
  # except that an ordinary or item cast may shorten it by a small fixed
  # slack; a proc or status cast may not shorten it at all.
  defp arm_act_delay(%{act_delay_until: until} = game_state, deadline, slack)
       when is_integer(until) and until != 0,
       do: %{game_state | act_delay_until: max(deadline, until - slack)}

  defp arm_act_delay(game_state, deadline, _slack), do: %{game_state | act_delay_until: deadline}

  @doc "A combo skill's resolved delay replaces its table entry, sizing the window it opens."
  @spec put_resolved_combo_delay(Definition.t(), pos_integer(), non_neg_integer()) ::
          Definition.t()
  def put_resolved_combo_delay(%{id: skill_id} = definition, level, delay)
      when skill_id in @combo_delay_skill_ids do
    %{
      definition
      | after_cast_delay: List.replace_at(definition.after_cast_delay, level - 1, delay)
    }
  end

  def put_resolved_combo_delay(definition, _level, _delay), do: definition

  @doc """
  The optional `dynamic_after_cast_delay/4` replaces this level's table entry
  on a cast-local definition, so the ordinary delay pipeline still applies.
  """
  @spec delay_definition(
          Active.caster(),
          module(),
          Active.target(),
          pos_integer(),
          Definition.t()
        ) ::
          Definition.t()
  def delay_definition(game_state, module, target, level, definition) do
    if function_exported?(module, :dynamic_after_cast_delay, 4) do
      base = module.dynamic_after_cast_delay(game_state, target, level, definition)
      table = pad_levels(definition.after_cast_delay, level)
      %{definition | after_cast_delay: List.replace_at(table, level - 1, base)}
    else
      definition
    end
  end

  defp pad_levels(table, level) when length(table) >= level, do: table
  defp pad_levels(table, level), do: table ++ List.duplicate(0, level - length(table))

  @doc """
  Lets a skill override its per-level cast-time table for this cast (Asura is
  instant as a combo follow-up). Skills without the callback take the
  definition unchanged, so their timing is byte-identical to the default path.
  """
  @spec cast_timing_definition(
          Active.caster(),
          module(),
          Active.target(),
          pos_integer(),
          Definition.t()
        ) :: Definition.t()
  def cast_timing_definition(game_state, module, target, level, definition) do
    if function_exported?(module, :dynamic_cast_time, 4) do
      %{cast_time: cast_time, fixed_cast_time: fixed_cast_time} =
        module.dynamic_cast_time(game_state, target, level, definition)

      %{
        definition
        | cast_time: List.replace_at(definition.cast_time, level - 1, cast_time),
          fixed_cast_time: List.replace_at(definition.fixed_cast_time, level - 1, fixed_cast_time)
      }
    else
      definition
    end
  end

  # Reads a folded equipment modifier off the caster's `stats.modifiers.equipment`
  # map, defaulting to 0 when the key is absent or the caster carries no equipment
  # slice (unequipped players, bare-map test fixtures). Keys are either a bare
  # destination atom (global `bonus` keys) or a `{family, skill_id}` tuple
  # (per-skill `bonus2` keys), both produced by the equip-script eval fold.
  @spec equip_modifier(Active.caster(), atom() | {atom(), integer()}) :: integer()
  defp equip_modifier(game_state, key) do
    case Map.get(game_state, :stats) do
      nil ->
        0

      stats ->
        stats
        |> Map.get(:modifiers, %{})
        |> Map.get(:equipment, %{})
        |> Map.get(key, 0)
    end
  end
end
