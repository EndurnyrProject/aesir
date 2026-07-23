defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash do
  @moduledoc """
  Bowling Bash (KN_BOWLINGBASH). A weapon splash strike that hits the target
  and every enemy within 2 cells of it, knocking each hit target back away
  from the caster.

  Ratio scales `100 + 40` percent per level. The strike always lands 2 hits;
  wielding a two-handed sword raises that to 3 hits when 2 or more enemies
  (including the primary target) are caught in the splash, and to 4 hits at
  4 or more. Knockback distance scales with level: 1 cell at levels 1-2, up
  to 5 cells at levels 9-10.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 62,
    name: :kn_bowlingbash,
    display_name: "Bowling Bash",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    splash_radius: 2,
    sp_cost: [13, 14, 15, 16, 17, 18, 19, 20, 21, 22]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: {x, y}}} <- Combat.resolve_combatant(target_id) do
      combatant = caster.__struct__.to_combatant(caster)

      enemy_count =
        combatant.map_name
        |> Combat.splash_targets({x, y}, definition.splash_radius, combatant)
        |> length()

      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: skill_ratio(level),
        hit_count: hit_count(caster, enemy_count),
        skip_crit: true
      ]

      caster
      |> Combat.execute_splash_attack({x, y}, definition.splash_radius, opts)
      |> Enum.each(&Combat.knockback(:mob, &1, caster.x, caster.y, knockback_distance(level)))

      {:ok, caster}
    end
  end

  @doc "The weapon-ratio percentage at `level`: 100 + 40 per level."
  @spec skill_ratio(pos_integer()) :: pos_integer()
  def skill_ratio(level), do: 100 + 40 * level

  @doc """
  The knockback distance at `level`: 1 cell at levels 1-2, rising by 1 cell
  every 2 levels, to 5 cells at levels 9-10.
  """
  @spec knockback_distance(pos_integer()) :: pos_integer()
  def knockback_distance(level), do: div(level + 1, 2)

  @doc """
  The hit count for a cast: 2 hits by default, raised to 3 with a
  two-handed sword when 2 or more enemies (including the primary target) are
  caught in the splash, and to 4 at 4 or more.
  """
  @spec hit_count(struct(), non_neg_integer()) :: 2 | 3 | 4
  def hit_count(caster, enemy_count) do
    if two_handed_sword?(caster) do
      cond do
        enemy_count >= 4 -> 4
        enemy_count >= 2 -> 3
        true -> 2
      end
    else
      2
    end
  end

  defp two_handed_sword?(%PlayerState{stats: %{equipment: equipment}}) do
    Stats.weapon_type(equipment) == :two_handed_sword
  end

  defp two_handed_sword?(_caster), do: false
end
