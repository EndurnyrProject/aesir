defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDesperado do
  @moduledoc """
  Desperado (GS_DESPERADO). Plants a 7x7 field centred on the caster for
  1000 ms. Every 100 ms each enemy standing on it is struck by one weapon hit
  of `100 + 50 * (level - 1)` percent, doubled while the caster holds Fallen
  Angel, with the chance of the cell it stands on (`cell_chance/2`). A target
  is rolled once per tick; the field lives its full duration and a hit never
  ends it.

  The cast end requires a revolver and ten bullets but spends none of them: the
  bullets are consumed when the field is deleted, however it ends
  (`defer_ammo`, settled once by `GroupLifecycle.cleanup/3`). A player's cast
  holds equipment changes for the field's 1000 ms (`equip_lock_after_cast`)
  and walking for the default 300 ms walk delay plus the skill's 1000 ms.

  Identical in both modes; only the database range differs (5 in renewal,
  absent in pre-renewal), which a self skill never checks.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 516,
    name: :gs_desperado,
    display_name: "Desperado",
    max_level: 10,
    requires: [],
    target_type: :self,
    damage_type: :damage,
    damage_kind: :weapon,
    range: [renewal: 5, pre_renewal: 0],
    element: :weapon,
    splash_radius: 3,
    require_weapon: [:revolver],
    require_ammo: [:bullet],
    ammo_qty: List.duplicate(10, 10),
    defer_ammo: true,
    equip_lock_after_cast: :duration1,
    sp_cost: Enum.map(1..10, &(30 + 2 * &1)),
    after_cast_delay: List.duplicate(1_000, 10),
    duration: List.duplicate(1_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active
  @behaviour Ground

  @splash 3
  @lifetime 1_000
  @interval 100

  # The reference's `default_walk_delay` (300) plus AfterCastWalkDelay (1000),
  # armed at cast end for a player (`skill_castend_id`).
  @player_walk_delay 1_300

  @impl Active
  def cast(caster, _target, level, definition) do
    caster = hold_walk(caster)
    opts = [state: deferred_ammo(caster, level, definition)]

    case Unit.place(caster, :gs_desperado, level, {caster.x, caster.y}, opts) do
      {:ok, _group} ->
        {:ok, caster}

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  @impl Ground
  def on_place(%Group{origin: origin}) do
    {:ok,
     %{
       cells: Layout.square(origin, @splash),
       state: %{},
       interval: @interval,
       duration: @lifetime,
       unit_range: 0
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        enemies = SplashTargets.eligible(refs, caster)
        Enum.filter(refs, &(&1 in enemies))

      {:error, _reason} ->
        []
    end
  end

  @impl Ground
  def on_unit_hit(%Group{origin: {cx, cy}} = group, {x, y}, target, _now) do
    with true <- :rand.uniform(100) - 1 < cell_chance(abs(x - cx), abs(y - cy)),
         {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id) do
      Combat.execute_skill_attack(caster, target,
        skill_id: definition().id,
        skill_level: group.level,
        skill_ratio: skill_ratio(group.caster_type, group.caster_id, group.level),
        skip_range: true
      )
    end

    {:ok, group}
  end

  @doc """
  The percent chance a unit on the cell `dx`, `dy` away from the centre is hit
  in one tick (the reference's unit `val1`): the cross two cells wide falls
  linearly with no diagonals, `36 - 12 * (max(dx, dy) - 1)` with the first
  ring counting as the centre; the corner region is `28 - 4 * dx - 4 * dy`;
  never below 1.
  """
  @spec cell_chance(non_neg_integer(), non_neg_integer()) :: pos_integer()
  def cell_chance(dx, dy) when dx < 2 or dy < 2,
    do: max(36 - 12 * max(max(dx, dy) - 1, 0), 1)

  def cell_chance(dx, dy), do: max(28 - 4 * dx - 4 * dy, 1)

  @doc "The hit's ratio in percent, doubled while the caster holds Fallen Angel."
  @spec skill_ratio(atom(), integer(), pos_integer()) :: pos_integer()
  def skill_ratio(caster_type, caster_id, level) do
    ratio = 100 + 50 * (level - 1)

    if StatusStorage.has_status?(caster_type, caster_id, :sc_fallen_angel),
      do: ratio * 2,
      else: ratio
  end

  defp hold_walk(%PlayerState{} = caster),
    do:
      PlayerState.apply_walk_delay(
        caster,
        @player_walk_delay,
        System.monotonic_time(:millisecond)
      )

  defp hold_walk(caster), do: caster

  defp deferred_ammo(%PlayerState{character_id: id}, level, definition) do
    case Definition.ammo_qty_at_level(definition, level) do
      0 -> %{}
      qty -> %{deferred_ammo: %{owner_type: :player, owner_id: id, qty: qty}}
    end
  end

  defp deferred_ammo(_caster, _level, _definition), do: %{}
end
