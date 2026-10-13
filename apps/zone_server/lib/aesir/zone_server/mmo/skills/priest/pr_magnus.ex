defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnus do
  @moduledoc """
  Magnus Exorcismus (PR_MAGNUS). A 33-cell holy field whose cells each strike the
  enemies within one cell of them, level times at 130% MATK against undead and
  demons. A unit is struck at most once every three seconds by all Magnus
  Exorcismus fields together.

  Renewal: every other enemy on the field takes 100% MATK per hit; a 4 s cast plus
  1 s fixed, a 1 s delay, a 6 s cooldown, and 4 to 13 s of field. Pre-renewal: only
  undead and demons are struck; a 15 s cast, a 4 s delay, no cooldown, and 5 to 14 s
  of field. Both modes cost 40 to 58 SP and one Blue Gemstone.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 79,
    name: :pr_magnus,
    display_name: "Magnus Exorcismus",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :holy,
    splash_radius: 3,
    hit_interval: 3_000,
    unit_duration: [
      renewal: Enum.to_list(4_000..13_000//1_000),
      pre_renewal: Enum.to_list(5_000..14_000//1_000)
    ],
    sp_cost: Enum.to_list(40..58//2),
    cast_time: [renewal: List.duplicate(4_000, 10), pre_renewal: List.duplicate(15_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 10), pre_renewal: List.duplicate(4_000, 10)],
    cooldown: [renewal: List.duplicate(6_000, 10), pre_renewal: []],
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  @footprint [
    {-1, -3},
    {0, -3},
    {1, -3},
    {-1, -2},
    {0, -2},
    {1, -2},
    {-3, -1},
    {-2, -1},
    {-1, -1},
    {0, -1},
    {1, -1},
    {2, -1},
    {3, -1},
    {-3, 0},
    {-2, 0},
    {-1, 0},
    {0, 0},
    {1, 0},
    {2, 0},
    {3, 0},
    {-3, 1},
    {-2, 1},
    {-1, 1},
    {0, 1},
    {1, 1},
    {2, 1},
    {3, 1},
    {-1, 2},
    {0, 2},
    {1, 2},
    {-1, 3},
    {0, 3},
    {1, 3}
  ]

  # NOTE: Fire Rain should destroy overlapping Magnus fields once it exists; that
  # removal belongs to Fire Rain's implementation.

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: {x, y}, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Enum.map(@footprint, fn {dx, dy} -> {x + dx, y + dy} end),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1,
       no_overlap: true,
       path_check: true
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_id) do
      hit(group, definition(), caster, target)
    end

    {:ok, group}
  end

  @spec hit(Group.t(), struct(), struct(), {atom(), integer()}) :: :ok
  defp hit(group, definition, caster, {unit_type, target_id}) do
    with {:ok, target} <- Combat.resolve_combatant(unit_type, target_id),
         ratio when is_integer(ratio) <- skill_ratio(target) do
      Combat.apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        group.skill_id,
        group.level,
        definition.element,
        ratio,
        hit_divisions: group.level
      )
    end

    :ok
  end

  # 130% against undead (defence element) and demons. Other targets take 100% in
  # renewal and are left untouched (nil) in pre-renewal.
  @spec skill_ratio(map()) :: pos_integer() | nil
  defp skill_ratio(target) do
    cond do
      RaceModifiers.undead_or_demon?(target) -> 130
      GameMode.mode() == :renewal -> 100
      true -> nil
    end
  end
end
