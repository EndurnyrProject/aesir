defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection do
  @moduledoc """
  Resurrection (`ALL_RESURRECTION`), reviving a player corpse or attacking a
  living undead enemy.

  Renewal references:
  - `db/re/skill_db.yml:2003-2052`
  - `src/map/skills/acolyte/resurrection.cpp:15-74`
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 54,
    name: :all_resurrection,
    display_name: "Resurrection",
    max_level: 4,
    target_type: :target_resurrection,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    element: :holy,
    cast_time: [4_800, 3_200, 1_600, 0],
    fixed_cast_time: [1_200, 800, 400, 0],
    after_cast_delay: [0, 1_000, 2_000, 3_000],
    sp_cost: List.duplicate(60, 4),
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  # NOTE: Normal-PvE only until Aesir has WoE, BG, PvP-score, Hell Power, and
  # resurrection-config concepts; add their rAthena gates/options here then.
  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _target_pid, target_state, unit_type} <- TargetResolver.resolve(target_id) do
      cond do
        unit_type == :player and Unit.corpse?(target_state) -> :ok
        Unit.living?(target_state) and undead?(target_state) -> :ok
        true -> {:error, :invalid_target}
      end
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, target_pid, target_state, unit_type} <- TargetResolver.resolve(target_id),
         target_kind <- target_kind(unit_type, target_state),
         :ok <-
           apply_resurrection(
             target_kind,
             caster,
             caster_id,
             target_id,
             target_pid,
             target_state,
             level,
             definition
           ) do
      {:ok, caster}
    end
  end

  defp target_kind(:player, target_state) do
    if Unit.corpse?(target_state), do: :corpse, else: living_undead_kind(target_state)
  end

  defp target_kind(_unit_type, target_state), do: living_undead_kind(target_state)

  defp living_undead_kind(target_state) do
    if Unit.living?(target_state) and undead?(target_state), do: :undead, else: :invalid
  end

  defp apply_resurrection(
         :corpse,
         _caster,
         caster_id,
         _target_id,
         target_pid,
         _target_state,
         level,
         _definition
       ) do
    PlayerSession.resurrect(target_pid, caster_id, hp_percent(level))
  end

  defp apply_resurrection(
         :undead,
         caster,
         _caster_id,
         target_id,
         _target_pid,
         target_state,
         level,
         definition
       ) do
    attack_undead(caster, target_id, target_state, level, definition)
  end

  defp apply_resurrection(
         :invalid,
         _caster,
         _caster_id,
         _target_id,
         _target_pid,
         _target_state,
         _level,
         _definition
       ),
       do: {:error, :invalid_target}

  defp hp_percent(level), do: Enum.at([10, 30, 50, 80], level - 1)

  defp attack_undead(caster, target_id, target_state, level, definition) do
    caster_stats = PlayerState.get_stats(caster)
    target_stats = target_state.__struct__.get_stats(target_state)

    if instant_kill?(target_state, caster_stats, target_stats, level) do
      Combat.execute_magic_attack(caster, target_id,
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 0,
        bonus_matk: target_stats.hp,
        element: definition.element,
        skip_range: true
      )
    else
      Combat.execute_magic_attack(caster, target_id,
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: level,
        element: definition.element,
        skip_range: true
      )
    end
  end

  defp instant_kill?(target_state, caster_stats, target_stats, level) do
    combatant = target_state.__struct__.to_combatant(target_state)

    Map.get(combatant, :class, :normal) != :boss and
      :rand.uniform(1_000) - 1 < instant_kill_score(caster_stats, target_stats, level)
  end

  @doc false
  @spec instant_kill_score(map(), map(), pos_integer()) :: non_neg_integer()
  def instant_kill_score(caster_stats, target_stats, level) do
    score =
      10 * level + caster_stats.luk + caster_stats.int + caster_stats.base_level + 300 -
        div(300 * target_stats.hp, target_stats.max_hp)

    min(score, 700)
  end

  defp undead?(target_state) do
    combatant = target_state.__struct__.to_combatant(target_state)

    RaceModifiers.undead?(combatant.race) or undead_element?(Map.get(combatant, :element))
  end

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
