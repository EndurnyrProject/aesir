defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscBreaker do
  @moduledoc """
  Soul Destroyer strikes one enemy with a weapon blow driven by the caster's STR
  and INT.

  Renewal: a range-4 weapon hit of 150 percent per level plus the caster's STR
  and INT, scaled by base level above 99. It can be critical, at half the
  caster's critical chance. 20 SP; a quarter-second cast plus a quarter-second
  fixed cast, a one-second after-cast delay and a quarter-second cooldown.

  Classic: a range-9 hit in two parts dealt as one. The weapon part is 100
  percent per level and ignores attack cards, so Enchant Deadly Poison and
  Advanced Katar Mastery do not raise it. The INT part is 500 plus 0 to 499 plus
  5 times the level times INT: it always lands, ignores element, takes the
  target's misc card resists and the skill damage rates, then passes the target's
  damage statuses on its own (Lex Aeterna doubles each part and ends only on
  this one) and the siege rate, and is added even when the weapon part misses.
  20 SP to level 5 and 30 after; a 0.7-second cast and an after-cast delay of one
  second plus 0.2 per level above 1. Kaupe would not end on the weapon part.

  Monsters cast it too, with their own STR, INT and level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 379,
    name: :asc_breaker,
    requires: [],
    display_name: "Soul Destroyer",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: [renewal: 4, pre_renewal: 9],
    ignore_atk_card: [renewal: false, pre_renewal: true],
    sp_cost: [
      renewal: List.duplicate(20, 10),
      pre_renewal: List.duplicate(20, 5) ++ List.duplicate(30, 5)
    ],
    cast_time: [renewal: List.duplicate(250, 10), pre_renewal: List.duplicate(700, 10)],
    fixed_cast_time: [renewal: List.duplicate(250, 10), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 10),
      pre_renewal: Enum.map(1..10, &(1_000 + 200 * (&1 - 1)))
    ],
    cooldown: [renewal: List.duplicate(250, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @default_rng &:rand.uniform/1

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_ref}, level, definition) do
    opts =
      [skill_id: definition.id, skill_level: level, skip_range: true, hit_divisions: 1] ++
        mode_opts(caster, level)

    case Combat.execute_skill_attack(caster, target_ref, opts) do
      {:error, _reason} = error -> error
      _dispatched -> {:ok, caster}
    end
  end

  @doc "The weapon ratio at `level` for a caster with `str_int` STR plus INT at `base_level`."
  @spec skill_ratio(pos_integer(), non_neg_integer(), non_neg_integer()) :: pos_integer()
  def skill_ratio(level, str_int, base_level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(150 * level + str_int, base_level)
      :pre_renewal -> 100 * level
    end
  end

  defp mode_opts(caster, level) do
    case GameMode.mode() do
      :renewal ->
        ratio = skill_ratio(level, stat(caster, :str) + stat(caster, :int), base_level(caster))
        [critical: true, critical_divisor: 2, skill_ratio: ratio]

      :pre_renewal ->
        misc = 500 + (rng().(500) - 1) + 5 * level * stat(caster, :int)
        [skip_crit: true, skill_ratio: skill_ratio(level, 0, 0), misc_part: misc]
    end
  end

  defp stat(%PlayerState{stats: stats}, name), do: Stats.get_effective_stat(stats, name)
  defp stat(%MobState{calculated: calculated}, name), do: Map.fetch!(calculated, name)

  defp base_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp base_level(%MobState{mob_data: %{level: level}}), do: level

  defp rng, do: Application.get_env(:zone_server, :soul_destroyer_rng, @default_rng)
end
