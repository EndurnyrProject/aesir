defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash do
  @moduledoc """
  Bowling Bash (KN_BOWLINGBASH). A weapon splash strike that hits the target
  and nearby enemies, knocking each hit target back away from the caster.

  Ratio scales `100 + 40` percent per level.

  Renewal: 100% plus 40% per level weapon damage in two hits over a 2-cell
  splash (three hits with a two-handed sword against two or more enemies, four
  against four or more), pushing 1 cell per two levels, with a 0.35 s fixed
  cast, 0.3 s delay, and 1 s cooldown. Pre-renewal: a 0.7 s variable cast; the
  hits push nothing, and the target instead rolls through other enemies as
  `Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash.Chain` describes, so a
  target that reaches an enemy is struck twice.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 62,
    name: :kn_bowlingbash,
    requires: [],
    display_name: "Bowling Bash",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 2,
    splash_radius: [renewal: 2, pre_renewal: 1],
    hit_count: [renewal: 2, pre_renewal: 1],
    knockback: [renewal: [1, 1, 2, 2, 3, 3, 4, 4, 5, 5], pre_renewal: 1],
    cast_time: [renewal: [], pre_renewal: List.duplicate(700, 10)],
    fixed_cast_time: [renewal: List.duplicate(350, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(1000, 10), pre_renewal: []],
    sp_cost: [13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
    damage_splash: [renewal: false, pre_renewal: true]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash.Chain
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, primary} <- Combat.resolve_combatant(target_id) do
      cast_at(GameMode.mode(), caster, primary, level, definition)
    end
  end

  @doc false
  @spec cast_at(GameMode.t(), struct(), struct(), pos_integer(), struct(), Chain.rng()) ::
          {:ok, struct()}
  def cast_at(mode, caster, primary, level, definition, rng \\ &chain_rng/1)

  def cast_at(:pre_renewal, caster, primary, level, definition, rng) do
    primary_ref = {primary.unit_type, primary.unit_id}

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level),
      skip_crit: true,
      skip_range: true,
      equipment_blow: false,
      delivery: {:splash, primary_ref}
    ]

    attack = fn ref -> Combat.execute_skill_attack(caster, ref, opts) end
    :ok = Chain.run(caster, primary_ref, level, attack, rng)
    {:ok, caster}
  end

  def cast_at(:renewal, caster, %{position: {x, y}} = primary, level, definition, _rng) do
    combatant = caster.__struct__.to_combatant(caster)

    enemy_count =
      combatant.map_name
      |> Combat.splash_targets({x, y}, definition.splash_radius, combatant)
      |> length()

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level),
      hit_divisions: hit_count(caster, enemy_count),
      skip_crit: true,
      base_distance: knockback_distance(level),
      origin: {caster.x, caster.y},
      native_target_types: [:mob],
      delivery: {:splash, {primary.unit_type, primary.unit_id}}
    ]

    _ = Combat.execute_splash_attack(caster, {x, y}, definition.splash_radius, opts)
    {:ok, caster}
  end

  defp chain_rng(bound), do: :rand.uniform(bound) - 1

  @doc "The weapon-ratio percentage at `level`: 100 + 40 per level."
  @spec skill_ratio(pos_integer()) :: pos_integer()
  def skill_ratio(level), do: 100 + 40 * level

  @doc """
  Renewal pushes 1 cell at levels 1-2, rising every 2 levels to 5 cells at
  levels 9-10. The pre-renewal value is the database's, which its hits zero.
  """
  @spec knockback_distance(pos_integer()) :: pos_integer()
  def knockback_distance(level) do
    case definition().knockback do
      distance when is_integer(distance) -> distance
      distances -> Enum.at(distances, level - 1)
    end
  end

  @doc """
  The hit divisions of one cast's attack on each target: one in classic; in
  renewal 2 by default, raised to 3 with a two-handed sword when 2 or more
  enemies (including the primary target) are caught in the splash, and to 4
  at 4 or more. One damage calculation is repeated that many times.
  """
  @spec hit_count(struct(), non_neg_integer()) :: 1 | 2 | 3 | 4
  def hit_count(caster, enemy_count) do
    case GameMode.mode() do
      :pre_renewal -> 1
      :renewal when enemy_count >= 4 -> if two_handed_sword?(caster), do: 4, else: 2
      :renewal when enemy_count >= 2 -> if two_handed_sword?(caster), do: 3, else: 2
      :renewal -> 2
    end
  end

  defp two_handed_sword?(%PlayerState{stats: %{equipment: equipment}}) do
    Stats.weapon_type(equipment) == :two_handed_sword
  end

  defp two_handed_sword?(_caster), do: false
end
