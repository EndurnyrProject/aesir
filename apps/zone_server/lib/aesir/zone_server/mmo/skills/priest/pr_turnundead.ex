defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrTurnundead do
  @moduledoc """
  Turn Undead (PR_TURNUNDEAD). Rolls an instant kill against an undead race or
  element enemy, otherwise a fallback. Either way the target takes a holy magic
  attack whose base is the target's HP (kill) or the fallback, ignoring MDEF and
  the caster's cards. Status-immune targets never roll the kill.

  Renewal: kill score 10 per level plus LUK, INT, and base level, plus 300 scaled by
  missing HP (cap 700 of 1000); the fallback base is a MATK roll times the level in
  percent; a 0.8 s cast plus 0.2 s fixed. Pre-renewal: 20 per level and a 200 HP
  term; the fallback base is base level plus INT plus 10 per level; a 1 s cast.
  Both modes reach 5 cells for 20 SP with a 3 s delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 77,
    name: :pr_turnundead,
    ignore_atk_card: true,
    display_name: "Turn Undead",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 5,
    cast_time: [renewal: List.duplicate(800, 10), pre_renewal: List.duplicate(1_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(200, 10), pre_renewal: []],
    after_cast_delay: List.duplicate(3_000, 10),
    sp_cost: List.duplicate(20, 10)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, target} <- Combat.resolve_combatant(target_id),
         true <- undead?(target) do
      :ok
    else
      false -> {:error, :invalid_target}
      {:error, _reason} = error -> error
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, _target_pid, target_state, _target_type} <- TargetResolver.resolve(target_id),
         combatant = target_state.__struct__.to_combatant(target_state),
         true <- undead?(combatant),
         target_stats <- target_state.__struct__.get_stats(target_state),
         caster_stats <- PlayerState.get_stats(caster),
         {:ok, _ref} <-
           apply_damage(caster, target_id, caster_stats, target_stats, level, definition,
             status_immune: Map.get(combatant, :status_immune, false)
           ) do
      {:ok, caster}
    else
      false -> {:error, :invalid_target}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  The instant-kill roll out of 1000, capped at 700.

  Renewal: 10 per level plus LUK, INT, and base level, plus 300 scaled down by the
  target's remaining HP fraction. Pre-renewal: 20 per level plus the same stats, plus
  200 scaled down the same way.
  """
  @spec instant_kill_score(map(), map(), pos_integer()) :: non_neg_integer()
  def instant_kill_score(caster_stats, target_stats, level) do
    {per_level, hp_term} = if GameMode.mode() == :renewal, do: {10, 300}, else: {20, 200}

    score =
      per_level * level + caster_stats.luk + caster_stats.int + caster_stats.base_level +
        hp_term - div(hp_term * target_stats.hp, target_stats.max_hp)

    min(score, 700)
  end

  defp apply_damage(caster, target_id, caster_stats, target_stats, level, definition, opts) do
    roll = :rand.uniform(1_000) - 1

    base =
      cond do
        roll < instant_kill_score(caster_stats, target_stats, level) and
            not Keyword.fetch!(opts, :status_immune) ->
          target_stats.hp

        GameMode.mode() == :renewal ->
          caster
          |> PlayerState.to_combatant()
          |> Map.fetch!(:combat_stats)
          |> MagicDamageCalculator.roll_matk()
          |> renewal_fallback_base(level)

        true ->
          fallback_damage(caster_stats, level)
      end

    Combat.execute_magic_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      element: definition.element,
      base_damage: base,
      ignore_mdef: true,
      skip_range: true
    )
  end

  @doc "Renewal's failed roll takes a MATK roll scaled by the skill level in percent."
  @spec renewal_fallback_base(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def renewal_fallback_base(matk, level), do: div(matk * level, 100)

  @doc "Pre-renewal's failed roll takes base level plus INT plus 10 per level."
  @spec fallback_damage(map(), pos_integer()) :: pos_integer()
  def fallback_damage(caster_stats, level),
    do: caster_stats.base_level + caster_stats.int + 10 * level

  defp undead?(target), do: RaceModifiers.undead_target?(target)
end
