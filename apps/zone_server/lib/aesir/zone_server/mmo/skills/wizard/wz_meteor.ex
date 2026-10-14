defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor do
  @moduledoc """
  Meteor Storm (WZ_METEOR). Drops 2 to 7 meteors, one per second, each on a
  random cell up to 3 cells from the target cell (10 meteors over 16 cells at
  the monster-only level 11). Each meteor is its own single-cell unit, placed
  at the cast: a cell on a wall or without a straight line to the caster drops
  no meteor. Meteor `i` starts falling `i - 1` seconds after the cast, shown to
  everyone in range, and lands 700 ms later, striking every enemy within 3
  cells of it in line of sight with one fire hit of several divisions that
  stuns 3% per level. A meteor whose caster is gone when it would start
  falling never falls; one landing on Land Protector strikes nobody.

  Renewal: each meteor strikes 2 to 7 times by level at 125% MATK per hit, with
  a 4.5 s stun, a 6.3 s cast plus 1.5 s fixed, a 1 s delay and a 2.5 to 7 s
  cooldown. Pre-renewal: each meteor strikes 1 to 5 times at 100% MATK per hit,
  with a 5 s stun, a 15 s variable cast, a 2 to 7 s delay and no cooldown.
  Level 11 strikes 15 times in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 83,
    name: :wz_meteor,
    requires: [],
    display_name: "Meteor Storm",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :fire,
    splash_radius: 3,
    hit_interval: 1_000,
    unit_duration: [renewal: List.duplicate(4_500, 10), pre_renewal: List.duplicate(5_000, 10)],
    duration: [2_000, 3_000, 3_000, 4_000, 4_000, 5_000, 5_000, 6_000, 6_000, 7_000],
    sp_cost: [20, 24, 30, 34, 40, 44, 50, 54, 60, 64],
    cast_time: [renewal: List.duplicate(6_300, 10), pre_renewal: List.duplicate(15_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(1_500, 10), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 10),
      pre_renewal: [2000, 3000, 3000, 4000, 4000, 5000, 5000, 6000, 6000, 7000]
    ],
    cooldown: [
      renewal: [2_500, 3_000, 3_500, 4_000, 4_500, 5_000, 5_500, 6_000, 6_500, 7_000],
      pre_renewal: []
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast

  @behaviour Ground

  @meteors [2, 3, 3, 4, 4, 5, 5, 6, 6, 7]
  @hits %{
    renewal: [2, 3, 3, 4, 4, 5, 5, 6, 6, 7],
    pre_renewal: [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
  }

  # A meteor lands 700 ms after it starts falling, whatever its interval.
  @fall_ms 700
  @unit_range 3

  @doc "The number of meteors dropped at `level`: 2 to 7, and 10 at level 11."
  @spec meteor_count(pos_integer()) :: pos_integer()
  def meteor_count(11), do: 10
  def meteor_count(level), do: Enum.at(@meteors, level - 1)

  @doc "Hits each meteor strikes at `level`: 2 to 7 in renewal, 1 to 5 in classic, 15 at level 11."
  @spec hits_per_meteor(pos_integer()) :: pos_integer()
  def hits_per_meteor(11), do: 15
  def hits_per_meteor(level), do: Enum.at(Map.fetch!(@hits, GameMode.mode()), level - 1)

  @doc "How far from the target cell a meteor may land: 3 cells, 16 at level 11."
  @spec scatter(pos_integer()) :: pos_integer()
  def scatter(11), do: 16
  def scatter(_level), do: 3

  @doc "Renewal deals 125% MATK per impact; classic 100%."
  @spec skill_ratio() :: pos_integer()
  def skill_ratio, do: if(GameMode.mode() == :renewal, do: 125, else: 100)

  @doc """
  The cells the meteors land on, in falling order: each a random cell within
  `scatter/1` of `{x, y}` (`rng.(n)` returns `0..n-1`).
  """
  @spec meteor_cells({integer(), integer()}, pos_integer(), (pos_integer() -> non_neg_integer())) ::
          [{integer(), integer()}]
  def meteor_cells({x, y}, level, rng \\ &(:rand.uniform(&1) - 1)) do
    area = scatter(level)

    for _meteor <- 1..meteor_count(level),
        do: {x - area + rng.(area * 2 + 1), y - area + rng.(area * 2 + 1)}
  end

  # Every meteor is placed at the cast; one whose cell is refused drops nothing.
  @doc false
  def cast(caster, {:ground, x, y}, level, _definition) do
    {x, y}
    |> meteor_cells(level)
    |> Enum.with_index(1)
    |> Enum.each(fn {cell, meteor} ->
      Unit.place(caster, :wz_meteor, level, cell, state: %{meteor: meteor})
    end)

    {:ok, caster}
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, state: %{meteor: meteor}}) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: %{falling: false, strike_on_expiry: true},
       interval: definition.hit_interval,
       initial_delay: (meteor - 1) * definition.hit_interval,
       duration: meteor * definition.hit_interval,
       unit_range: @unit_range,
       path_check: true,
       announce: false,
       lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action}
     }}
  end

  # The meteor starts falling, shown at its cell, and lands 700 ms later.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{state: %{falling: false, meteor: meteor} = state} = group, _now) do
    {x, y} = group.center

    packet = %GroundSkill{
      skill_id: group.skill_id,
      src_id: group.caster_id,
      level: group.level,
      x: x,
      y: y,
      server_tick: ServerTick.now()
    }

    Broadcast.to_in_range(group.map_name, x, y, Config.view_range(), packet)

    expires_at = group.created_at + (meteor - 1) * group.interval + @fall_ms
    {:ok, %{group | expires_at: expires_at, state: %{state | falling: true}}}
  end

  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{state: %{falling: true}} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  def unit_targets(%Group{}, _cell, _refs), do: []

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, {unit_type, target_id}, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id) do
      Combat.apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        group.skill_id,
        group.level,
        definition().element,
        skill_ratio(),
        hit_divisions: hits_per_meteor(group.level),
        additional_effect: fn _source, ref -> stun(group, ref) end
      )
    end

    {:ok, group}
  end

  # The Stun roll is each impact's additional effect.
  defp stun(group, {unit_type, target_id}) do
    StatusInterpreter.apply_status(unit_type, target_id, :sc_stun,
      val1: group.level,
      duration: hd(definition().unit_duration),
      success_rate: 3 * group.level,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end
end
