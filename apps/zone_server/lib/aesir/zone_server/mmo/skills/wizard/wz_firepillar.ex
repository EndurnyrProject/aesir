defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillar do
  @moduledoc """
  Fire Pillar (WZ_FIREPILLAR). A single-cell fire field that waits up to 30 s
  for an enemy to come within one cell of it, then becomes an active pillar for
  one second. The active pillar bursts once, on the first pass that finds an
  enemy within one cell of it, over the splash area (one cell up to level 5,
  two above); an active pillar that finds nobody fades unused. A waiting pillar
  on Land Protector ends without becoming active.

  The burst strikes level plus 2 times at 40% plus 20% per level MATK (a player's damage
  is split across the hits) for 75 SP, needing a Blue Gemstone from level 6
  (`dynamic_item_cost/4`, as the item cost field cannot express a level threshold).
  Renewal casts in 0.19 to 1.92 s plus a fixed part; pre-renewal in 0.3 to 3 s. The
  two modes otherwise agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 80,
    name: :wz_firepillar,
    active_instance: 5,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    is_trap: [renewal: false, pre_renewal: true],
    requires: [:inventory],
    display_name: "Fire Pillar",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    element: :fire,
    range: 9,
    hit_count: Enum.to_list(3..12),
    splash_radius: 2,
    hit_interval: 2_000,
    unit_duration: List.duplicate(30_000, 10),
    cast_time: [
      renewal: [1920, 1728, 1536, 1344, 1152, 960, 768, 576, 384, 192],
      pre_renewal: [3000, 2700, 2400, 2100, 1800, 1500, 1200, 900, 600, 300]
    ],
    fixed_cast_time: [renewal: [480, 432, 384, 336, 288, 240, 192, 144, 96, 48], pre_renewal: []],
    after_cast_delay: List.duplicate(1000, 10),
    sp_cost: List.duplicate(75, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @blue_gemstone 717
  @active_duration 1_000
  @behaviour Ground

  @doc "Fire Pillar needs one Blue Gemstone from level 6."
  @spec dynamic_item_cost(map(), term(), pos_integer(), struct()) :: [map()]
  def dynamic_item_cost(_caster, _target, level, _definition) when level < 6, do: []

  def dynamic_item_cost(_caster, _target, _level, _definition),
    do: [%{id: @blue_gemstone, amount: 1}]

  @doc false
  @spec cast(map(), {:ground, integer(), integer()}, pos_integer(), struct()) ::
          {:ok, map()} | {:error, term()}
  def cast(caster, {:ground, x, y}, level, _definition) do
    case Unit.place(caster, :wz_firepillar, level, {x, y}) do
      {:ok, _group} ->
        {:ok, caster}

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: %{
         phase: :waiting,
         hit_budget: hit_count(level)
       },
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{state: %{phase: phase}} = group, _cell, refs)
      when phase in [:waiting, :active] do
    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  def unit_targets(%Group{}, _cell, _refs), do: []

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) ::
          {:ok, Group.t()} | {:expire, Group.t()}
  def on_unit_hit(%Group{state: %{phase: :waiting}} = group, _cell, _target, now) do
    {x, y} = group.center

    cond do
      not match?({:ok, _caster}, Combat.resolve_combatant(group.caster_id)) -> {:ok, group}
      Storage.land_protected?(group.map_name, x, y) -> {:expire, group}
      true -> {:ok, activate(group, now)}
    end
  end

  # The active pillar is a new unit: it acts from the next pass on.
  def on_unit_hit(%Group{state: %{phase: :active, activated_at: at}} = group, _cell, _target, now)
      when now > at do
    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        group
        |> impact_targets(caster)
        |> Enum.each(&hit_target(&1, group.state.hit_budget, caster, group, definition()))

        {:ok, %{group | state: %{group.state | phase: :used}}}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  def on_unit_hit(%Group{} = group, _cell, _target, _now), do: {:ok, group}

  defp activate(%Group{state: state} = group, now) do
    %{
      group
      | expires_at: now + @active_duration,
        state:
          Map.merge(state, %{
            phase: :active,
            activated_at: now,
            unit_generation: Map.get(state, :unit_generation, 0) + 1
          })
    }
  end

  @spec impact_targets(Group.t(), struct()) :: [{atom(), integer()}]
  defp impact_targets(%Group{} = group, caster) do
    Combat.splash_targets(group.map_name, group.center, splash_radius(group.level), caster)
  end

  @spec hit_target({atom(), integer()}, pos_integer(), struct(), Group.t(), struct()) :: :ok
  defp hit_target({unit_type, target_id}, hits, caster, group, definition) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      group.level,
      definition.element,
      skill_ratio(group.level),
      bonus_matk: 100 + 50 * group.level,
      hit_divisions: hits,
      divide_hits_for_player?: true
    )
  end

  @spec hit_count(pos_integer()) :: pos_integer()
  defp hit_count(level), do: level + 2

  @spec splash_radius(pos_integer()) :: 1 | 2
  defp splash_radius(level) when level <= 5, do: 1
  defp splash_radius(_level), do: 2

  @spec skill_ratio(pos_integer()) :: pos_integer()
  defp skill_ratio(level), do: 40 + 20 * level
end
