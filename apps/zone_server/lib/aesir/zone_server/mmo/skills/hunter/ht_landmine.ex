defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine do
  @moduledoc """
  Land Mine (HT_LANDMINE). Hunter single-cell ground trap dealing BF_MISC damage.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this single-cell trap at the target cell. The trap is live immediately
  and triggers once when a hostile unit (mob; not the owner or allies) steps onto
  it: it deals Earth BF_MISC damage via `Combat.execute_misc_attack` and is
  consumed (`:expire`).

  The per-level base damage is stamped at placement from the placer's stats and
  the per-trigger ± variance is rolled at fire time (see `Skills.Trap`).

  Verified vs rAthena: skill id 116, Earth element, Range 3 (skill_db.yml:4230);
  the damage formula lives in `Skills.Trap` (battle.cpp:6354). Hunter is not a
  reachable job, so this ships as a castable module + tests, not in a job tree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 116,
    name: :ht_landmine,
    display_name: "Land Mine",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :misc,
    element: :earth,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [30_000, 30_000, 30_000, 30_000, 30_000],
    sp_cost: [10, 12, 14, 16, 18]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: ct, caster_id: cid} = group) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(ct, cid)

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visible?: false
     }}
  end

  # Traps have no periodic effect; they only react to on_touch and expire on
  # their duration. NOTE: a no-op tick at hit_interval; harmless until the trap
  # triggers or expires.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover) do
      fire(group, mover)
    else
      {:ok, group}
    end
  end

  defp fire(%Group{state: %{base_damage: base_damage}} = group, {_mover_type, mover_id}) do
    definition = definition()

    case Trap.resolve_caster(group) do
      {:ok, caster_state} ->
        Combat.execute_misc_attack(caster_state, mover_id,
          skill_id: definition.id,
          skill_level: group.level,
          base_damage: Trap.roll_damage(base_damage),
          element: definition.element
        )

        :expire

      :error ->
        {:ok, group}
    end
  end
end
