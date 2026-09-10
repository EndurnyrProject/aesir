defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAcidterror do
  @moduledoc """
  Acid Terror (AM_ACIDTERROR). A neutral acid strike thrown from 9 cells that
  never misses, rolls 3 per level percent bleeding, and may break the armor.

  Renewal: 200 per level percent (plus 100 with Learning Potion), only the status
  DEF is ignored, a 0.5 s cast plus 0.5 s fixed, a 0.5 s delay, 108 s bleeding,
  and a 10 per level minus 5 percent armor break. Pre-renewal: 50 plus 50 per
  level percent, hard DEF ignored while the target's soft DEF is taken off the
  attack before the ratio, a 1 s cast, 120 s bleeding, and a 3/7/10/12/13 percent
  armor break.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 230,
    name: :am_acidterror,
    requires: [],
    display_name: "Acid Terror",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :neutral,
    range: 9,
    hit_count: 1,
    sp_cost: List.duplicate(15, 5),
    item_cost: [%{id: 7136, amount: 1}],
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: []]

  require Logger

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level, learning_potion_level(caster)),
      element: :neutral,
      ignore_flee: true,
      skip_crit: true,
      skip_range: true,
      report_hit: true
    ]

    case Combat.execute_acid_terror_attack(caster, target_id, opts) do
      {:ok, %{hit?: true}} ->
        apply_on_hit(target_id, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec skill_ratio(pos_integer(), non_neg_integer()) :: pos_integer()
  def skill_ratio(level, learning_potion_level) do
    case GameMode.mode() do
      :renewal -> 200 * level + if(learning_potion_level > 0, do: 100, else: 0)
      :pre_renewal -> 50 + 50 * level
    end
  end

  defp learning_potion_level(%{stats: %{progression: %{learned_skills: learned_skills}}}) do
    case Catalog.by_name(:am_learningpotion) do
      {:ok, %{id: skill_id}} -> Learned.learned_level(learned_skills, skill_id)
      :error -> 0
    end
  end

  defp learning_potion_level(_caster), do: 0

  defp apply_on_hit(target_id, level) do
    case TargetResolver.resolve(target_id) do
      {:ok, target_pid, target_state, target_type} ->
        StatusInterpreter.apply_status(target_type, target_id, :sc_bleeding,
          duration: bleeding_duration(),
          success_rate: 3 * level
        )

        maybe_break_armor(target_pid, target_id, target_type, target_state, level)

      {:error, reason} ->
        Logger.warning(
          "Acid Terror could not resolve hit target #{target_id}: #{inspect(reason)}"
        )
    end
  end

  defp maybe_break_armor(target_pid, target_id, :player, %{stats: stats}, level) do
    level
    |> armor_break_rate()
    |> EquipBreak.resolve_slot({:player, target_id, stats}, :armor, [])
    |> Enum.each(fn {:target, :armor} -> PlayerSession.break_equip(target_pid, :armor) end)
  end

  defp maybe_break_armor(_target_pid, _target_id, _target_type, _target_state, _level), do: :ok

  defp armor_break_rate(level) do
    case GameMode.mode() do
      :renewal -> (10 * level - 5) * 100
      :pre_renewal -> Enum.at([300, 700, 1_000, 1_200, 1_300], level - 1)
    end
  end

  defp bleeding_duration do
    case GameMode.mode() do
      :renewal -> 108_000
      :pre_renewal -> 120_000
    end
  end
end
