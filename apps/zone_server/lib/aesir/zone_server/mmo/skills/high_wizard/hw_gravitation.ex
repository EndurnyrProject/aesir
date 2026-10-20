defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGravitation do
  @moduledoc """
  Gravitation Field (HW_GRAVITATION). A ground spell up to 18 cells away.

  Renewal: an instant neutral burst of `2 * level` magic hits at
  `100 * level` percent MATK scaled by base level / 100 on every enemy within two
  cells of the target cell with line of sight; nothing when that cell is under
  Land Protector. 60 to 100 SP, 5 s cast plus 1 s
  fixed, 1 s after-cast delay and a 5 s cooldown.

  Pre-renewal: a 5x5 field lasting `4 + level` seconds that deals a fixed
  `200 + 200 * level` misc damage to every enemy inside, once a second for all
  Gravitation fields together, timed from when a field first reached it (400 to the
  Emperium; no FLEE, DEF, element or damage-reducing status) and slows their attack speed by 5% per level through
  `:sc_gravitation`. The caster holds the same status bound to the field: they
  cannot walk or use items while it lasts, taking damage collapses it, and no
  other skill of theirs deals damage (`StatusInterpreter.can_deal_skill_damage?/4`;
  the field's own ticks and equipment procs still do). It is a no-damage skill:
  its hits never set off the target's when-hit equipment procs. 20 to 100 SP, one
  Blue Gemstone, 5 s cast and a 5 to 9 s after-cast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 484,
    name: :hw_gravitation,
    display_name: "Gravitation Field",
    max_level: 5,
    target_type: :ground,
    damage_type: [renewal: :damage, pre_renewal: :no_damage],
    ignore_def_card: [renewal: false, pre_renewal: true],
    ignore_element: [renewal: false, pre_renewal: true],
    ignore_flee: [renewal: false, pre_renewal: true],
    damage_kind: [renewal: :magic, pre_renewal: :misc],
    element: [renewal: :neutral, pre_renewal: :earth],
    range: 18,
    splash_radius: 2,
    hit_count: [renewal: [2, 4, 6, 8, 10], pre_renewal: 1],
    sp_cost: [renewal: [60, 70, 80, 90, 100], pre_renewal: [20, 40, 60, 80, 100]],
    cast_time: List.duplicate(5_000, 5),
    fixed_cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 5),
      pre_renewal: [5_000, 6_000, 7_000, 8_000, 9_000]
    ],
    cooldown: [renewal: List.duplicate(5_000, 5), pre_renewal: []],
    item_cost: [renewal: [], pre_renewal: [%{id: 717, amount: 1}]],
    unit_duration: [5_000, 6_000, 7_000, 8_000, 9_000],
    hit_interval: 1_000,
    target_hidden: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground

  @emperium 1288

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def cast(%PlayerState{} = caster, {:ground, x, y}, level, definition) do
    case GameMode.mode() do
      :renewal -> burst(caster, {x, y}, level, definition)
      :pre_renewal -> channel(caster, {x, y}, level, definition)
    end
  end

  # The renewal field is one cell reaching two around; Land Protector on that
  # cell keeps it from forming.
  defp burst(%PlayerState{map_name: map} = caster, {x, y} = center, level, definition) do
    if not Storage.land_protected?(map, x, y), do: hit_area(caster, center, level, definition)
    {:ok, caster}
  end

  defp hit_area(caster, center, level, definition) do
    Combat.execute_magic_splash(caster, center, definition.splash_radius,
      skill_id: definition.id,
      skill_level: level,
      hit_divisions: Definition.hit_count_at_level(definition, level),
      element: definition.element,
      skill_ratio: LevelModifier.skill_ratio(100 * level, caster.stats.progression.base_level),
      line_of_sight: true
    )
  end

  defp channel(%PlayerState{} = caster, center, level, definition) do
    case Unit.place(caster, :hw_gravitation, level, center) do
      {:ok, %Group{group_id: group_id}} ->
        lock(caster, group_id, level, definition)

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  # The reference ignores a refused self status, so the placed field stays and
  # the cast succeeds with its requirement paid.
  defp lock(%PlayerState{character_id: id} = caster, group_id, level, definition) do
    StatusInterpreter.apply_status(:player, id, :sc_gravitation,
      val1: level,
      caster_id: id,
      duration: Enum.at(definition.unit_duration, level - 1),
      state: %{self?: true, group_id: group_id}
    )

    {:ok, caster}
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       path_check: true,
       unit_range: 0,
       no_overlap: true,
       lifecycle_policy: %LifecyclePolicy{on_caster_loss: :expire}
     }}
  end

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{} = group) do
    %{status_type: :sc_gravitation, params: [val1: group.level], target?: &enemy?(group, &1)}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs) do
    case UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      {:ok, {_module, caster, _pid}} ->
        SplashTargets.eligible(refs, caster.__struct__.to_combatant(caster))

      _unavailable ->
        []
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, _now) do
    with {:ok, {_module, caster, _pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      SkillAttack.execute_misc_attack(caster, target,
        skill_id: group.skill_id,
        skill_level: group.level,
        base_damage: tick_damage(target, group.level),
        bypass_reductions: true,
        delivery: :unit
      )
    end

    {:ok, group}
  end

  @doc "Pre-renewal tick damage: `200 + 200 * level`, a flat 400 against the Emperium."
  @spec tick_damage({atom(), integer()}, pos_integer()) :: pos_integer()
  def tick_damage({:mob, id}, level) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_module, %MobState{mob_id: @emperium}, _pid}} -> 400
      _other -> 200 + 200 * level
    end
  end

  def tick_damage(_target, level), do: 200 + 200 * level

  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{caster_type: type, caster_id: id, group_id: group_id}) do
    case StatusStorage.get_status(type, id, :sc_gravitation) do
      %StatusEntry{state: %{self?: true, group_id: ^group_id}} ->
        StatusInterpreter.remove_status(type, id, :sc_gravitation)

      _other ->
        :ok
    end

    :ok
  end

  defp enemy?(%Group{} = group, {target_type, target_id}) do
    with {:ok, {_module, caster, _pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id),
         {:ok, {_module, target, _pid}} <- UnitRegistry.get_unit(target_type, target_id) do
      Targeting.validate_enemy(caster, target) == :ok
    else
      _unavailable -> false
    end
  end
end
