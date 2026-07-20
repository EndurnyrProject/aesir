defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillar do
  @moduledoc """
  Fire Pillar (WZ_FIREPILLAR). A single-cell, waiting Fire field that explodes
  when an enemy enters its activation area.

  It waits for up to 30 seconds, then an enemy within its Range-1 activation area
  activates a one-second Fire burst over the canonical splash area. The burst's hit count
  is level + 2 and its target delay is the Renewal `Duration2` table.

  Verified against rAthena Renewal: `db/re/skill_db.yml:2861-3014`,
  `src/map/skills/mage/firepillar.cpp:12-31`, `src/map/battle.cpp:5993-6001`,
  and `src/map/skill.cpp:5833-5839, 6975-6978, 7086-7125, 12455-12460`.
  The level-gated Blue Gemstone requirement is local because
  `Skill.Definition.item_cost` cannot express a level threshold.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 80,
    name: :wz_firepillar,
    display_name: "Fire Pillar",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    element: :fire,
    range: 9,
    hit_count: 3,
    splash_radius: 2,
    hit_interval: 2_000,
    unit_duration: List.duplicate(30_000, 10),
    cast_time: [1920, 1728, 1536, 1344, 1152, 960, 768, 576, 384, 192],
    fixed_cast_time: [480, 432, 384, 336, 288, 240, 192, 144, 96, 48],
    after_cast_delay: List.duplicate(1000, 10),
    sp_cost: List.duplicate(75, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit.ItemContainer

  @blue_gemstone 717
  @activation_radius 1
  @active_duration 1_000
  @behaviour Ground

  @doc false
  @spec validate(map(), term(), pos_integer(), struct()) :: :ok | {:error, :missing_catalyst}
  def validate(%{inventory: _inventory}, _target, level, _definition) when level < 6, do: :ok

  def validate(%{inventory: inventory}, _target, _level, _definition) do
    if ItemContainer.held_amount(inventory, @blue_gemstone) > 0,
      do: :ok,
      else: {:error, :missing_catalyst}
  end

  @doc false
  @spec cast(map(), {:ground, integer(), integer()}, pos_integer(), struct()) ::
          {:ok, map()} | {:error, term()}
  def cast(caster, {:ground, x, y}, level, _definition) do
    case Unit.place(caster, :wz_firepillar, level, {x, y}) do
      {:ok, _group} -> {:ok, consume_blue_gemstone(caster, level)}
      {:error, _reason} = error -> error
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
         hit_budget: hit_count(level),
         target_delay: target_delay(level)
       },
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{state: %{phase: :waiting}} = group, now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_id),
         [_ | _] <- activation_targets(group) do
      activate(group, caster, now)
    else
      _ -> {:ok, group}
    end
  end

  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_touch(%Group{state: %{phase: :waiting}} = group, mover) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_id),
         true <- mover in activation_targets(group) do
      activate(group, caster, System.monotonic_time(:millisecond))
    else
      _ -> {:ok, group}
    end
  end

  def on_touch(%Group{} = group, _mover), do: {:ok, group}

  @spec activate(Group.t(), struct(), integer()) :: {:ok, Group.t()}
  defp activate(%Group{state: %{hit_budget: hits}} = group, caster, now) do
    definition = definition()

    group
    |> impact_targets()
    |> Enum.each(&hit_target(&1, hits, caster, group, definition))

    {:ok,
     %{
       group
       | state: %{group.state | phase: :active, hit_budget: 0},
         next_tick_at: nil,
         expires_at: now + @active_duration
     }}
  end

  @spec activation_targets(Group.t()) :: [{atom(), integer()}]
  defp activation_targets(%Group{} = group) do
    Combat.splash_targets(group.map_name, group.center, @activation_radius, group.caster_id)
  end

  @spec impact_targets(Group.t()) :: [{atom(), integer()}]
  defp impact_targets(%Group{} = group) do
    Combat.splash_targets(
      group.map_name,
      group.center,
      splash_radius(group.level),
      group.caster_id
    )
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
      hit_count: hits,
      dst_delay: group.state.target_delay,
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

  @spec target_delay(pos_integer()) :: pos_integer()
  defp target_delay(level), do: 400 + 200 * level

  defp consume_blue_gemstone(caster, level) when level < 6, do: caster

  defp consume_blue_gemstone(caster, _level) do
    case ItemContainer.stackable_index(caster.inventory, @blue_gemstone) do
      nil ->
        caster

      index ->
        {:ok, inventory, change} = ItemContainer.remove(caster.inventory, index, 1)

        %{
          caster
          | inventory: inventory,
            pending_inventory_persist:
              caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
        }
    end
  end
end
