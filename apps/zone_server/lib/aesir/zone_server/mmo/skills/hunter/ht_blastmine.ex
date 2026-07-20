defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine do
  @moduledoc """
  Blast Mine (HT_BLASTMINE). Hunter ground trap dealing 3x3-splash BF_MISC damage.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this trap at the target cell with a 3x3 footprint (`Layout.square/2`).
  The trap is live immediately and triggers once when a hostile unit (mob; not
  the owner or allies) steps onto any footprint cell: it deals Wind BF_MISC
  damage across a 3x3 splash via `Combat.execute_misc_splash` and is consumed
  (`:expire`).

  The per-level base damage is stamped at placement from the placer's stats and
  the per-trigger ± variance is rolled at fire time (see `Skills.Trap`).

  Verified vs rAthena: skill id 122, Wind element (skill_db.yml:4535), Range 3
  (skill_db.yml:4532), SplashArea 1; the damage formula lives in `Skills.Trap`
  (battle.cpp:6354). The current 3x3 footprint means any of the 9 cells triggers
  (rAthena's Blast Mine is a single-cell trigger with a 3x3 splash - a remaining
  minor fidelity item). The splash damage hits every non-owner unit in the area
  (ally/faction filtering is future work). Hunter is not a reachable job, so this
  ships as a castable module + tests, not in a job tree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 122,
    name: :ht_blastmine,
    display_name: "Blast Mine",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :misc,
    element: :wind,
    range: 3,
    splash_radius: 1,
    hit_interval: 1_000,
    unit_duration: [25_000, 25_000, 25_000, 25_000, 25_000],
    sp_cost: [10, 12, 14, 16, 18]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: ct, caster_id: cid}) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(ct, cid)

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: Trap.place_state(level, stats),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  # Traps have no periodic effect; they only react to on_touch and expire on
  # their duration. NOTE: a no-op tick at hit_interval; harmless until trigger.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover) do
      fire(group)
    else
      {:ok, group}
    end
  end

  defp fire(%Group{center: center, state: %{base_damage: base_damage}} = group) do
    definition = definition()

    case Trap.resolve_caster(group) do
      {:ok, caster_state} ->
        Combat.execute_misc_splash(caster_state, center, definition.splash_radius,
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
