defmodule Aesir.ZoneServer.Mmo.Skills.PrTurnundead do
  @moduledoc """
  Turn Undead (PR_TURNUNDEAD). Targets undead race or element enemies, rolling
  the Renewal instant-kill score before falling back to level-scaled Holy MATK.

  rAthena renewal: `src/map/battle.cpp:5900-5922` and
  `src/map/skills/acolyte/turnundead.cpp:11-17`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 77,
    name: :pr_turnundead,
    display_name: "Turn Undead",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 5,
    cast_time: List.duplicate(800, 10),
    fixed_cast_time: List.duplicate(200, 10),
    after_cast_delay: List.duplicate(3_000, 10),
    sp_cost: List.duplicate(20, 10)

  alias Aesir.ZoneServer.Mmo.Combat
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
         true <- undead?(target_state.__struct__.to_combatant(target_state)),
         target_stats <- target_state.__struct__.get_stats(target_state),
         caster_stats <- PlayerState.get_stats(caster),
         :ok <- apply_damage(caster, target_id, caster_stats, target_stats, level, definition) do
      {:ok, caster}
    else
      false -> {:error, :invalid_target}
      {:error, _reason} = error -> error
    end
  end

  @doc false
  @spec instant_kill_score(map(), map(), pos_integer()) :: non_neg_integer()
  def instant_kill_score(caster_stats, target_stats, level) do
    score =
      10 * level + caster_stats.luk + caster_stats.int + caster_stats.base_level + 300 -
        div(300 * target_stats.hp, target_stats.max_hp)

    min(score, 700)
  end

  defp apply_damage(caster, target_id, caster_stats, target_stats, level, definition) do
    if :rand.uniform(1_000) - 1 < instant_kill_score(caster_stats, target_stats, level) do
      Combat.execute_magic_damage(caster, target_id, target_stats.hp,
        skill_id: definition.id,
        skill_level: level,
        element: definition.element,
        skip_range: true
      )
    else
      Combat.execute_magic_attack(caster, target_id,
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: fallback_skill_ratio(level),
        hit_count: 1,
        element: definition.element,
        ignore_mdef: true,
        skip_range: true
      )
    end
  end

  @doc false
  @spec fallback_skill_ratio(pos_integer()) :: pos_integer()
  def fallback_skill_ratio(level), do: 100 * level

  defp undead?(%{race: race} = target),
    do: RaceModifiers.undead?(race) or undead_element?(Map.get(target, :element))

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
