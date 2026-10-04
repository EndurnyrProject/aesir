defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSpiderweb do
  @moduledoc """
  Fiber Lock (PF_SPIDERWEB). Throws a web under an enemy up to 9 cells away for
  one Spiderweb: the web pulls the target to its cell and roots it with half
  FLEE (`:sc_spiderweb`) for 8 s (4 s on versus maps). Up to three webs stack on
  one unit, each extending the hold to at least 16 s for the second web in
  normal play, or 8, 12 s for the second and third on versus maps. Fire damage
  burns every web at once and is strengthened. A caster keeps at most three
  webs; a web on its own lasts 16 s.

  Renewal: 30 SP. Pre-renewal: 50 SP. Monsters cast it through `mob_cast/5`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 405,
    name: :pf_spiderweb,
    requires: [],
    display_name: "Fiber Lock",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: [renewal: [30], pre_renewal: [50]],
    item_cost: [%{id: 1025, amount: 1}],
    unit_duration: [16_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground

  @max_webs 3

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, term()}
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, %{position: cell, unit_type: type}} <- Combat.resolve_combatant(target_id),
         :ok <- web(caster, {type, target_id}, level, cell) do
      {:ok, caster}
    end
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, term()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, _definition, _row) do
    with {:ok, %{position: cell}} <- Combat.resolve_combatant(type, id) do
      web(caster, {type, id}, level, cell)
    end
  end

  # The Manager fires no on_touch for a unit already standing on a new group's
  # cell, so the victim is captured right after placement.
  defp web(caster, victim, level, cell) do
    with {:ok, group} <- Unit.place(caster, :pf_spiderweb, level, cell, state: %{victim: victim}) do
      capture(group, victim)
    end
  end

  @doc """
  Catches `victim` in `group`'s web: roots and pulls it on the first web, or
  appends the web and extends the hold on the second and third. A unit already
  held by three webs, or stepping back onto a web that holds it, is unaffected.
  """
  @spec capture(Group.t(), {atom(), integer()}) :: :ok
  def capture(%Group{group_id: gid, map_name: map} = group, {type, id}) do
    versus? = Targeting.versus_map?(map)
    web_ms = if versus?, do: 4_000, else: 8_000

    case StatusStorage.get_status(type, id, :sc_spiderweb) do
      %StatusEntry{state: %{groups: groups}} ->
        if gid in groups or length(groups) >= @max_webs,
          do: :ok,
          else: extend_hold(type, id, gid, web_ms * stack_factor(length(groups) + 1, versus?))

      nil ->
        first_hold(group, {type, id}, web_ms)
    end
  end

  defp extend_hold(type, id, gid, hold_ms) do
    hold_until = System.monotonic_time(:millisecond) + hold_ms

    StatusStorage.update_status(type, id, :sc_spiderweb, fn entry ->
      %{
        entry
        | state: Map.put(entry.state, :groups, entry.state.groups ++ [gid]),
          expires_at: max(entry.expires_at, hold_until)
      }
    end)
  end

  defp first_hold(%Group{group_id: gid, center: {x, y}} = group, {type, id}, web_ms) do
    with :ok <-
           StatusInterpreter.apply_status(type, id, :sc_spiderweb,
             duration: web_ms,
             caster_id: group.caster_id,
             source_type: group.caster_type,
             state: %{groups: [gid]}
           ) do
      Knockback.pull_to(type, id, x, y)
    end

    :ok
  end

  # Normal play: 8 s, then 16 s for the second web, then 8 s again. Versus maps
  # scale with the stack: 4, 8, 12 s. The hold never shortens.
  defp stack_factor(stack, true), do: stack
  defp stack_factor(2, false), do: 2
  defp stack_factor(_stack, false), do: 1

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center}) do
    {:ok,
     %{
       cells: [center],
       state: %{},
       interval: 1_000,
       duration: hd(definition().unit_duration),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: @max_webs}
     }}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_touch(%Group{} = group, mover) do
    if enemy?(group, mover), do: capture(group, mover)
    {:ok, group}
  end

  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{group_id: gid, state: %{victim: {type, id}}}) do
    case StatusStorage.get_status(type, id, :sc_spiderweb) do
      %StatusEntry{state: %{groups: groups}} ->
        if groups -- [gid] == [],
          do: StatusInterpreter.remove_status(type, id, :sc_spiderweb),
          else: drop_web(type, id, gid)

      nil ->
        :ok
    end

    :ok
  end

  def on_expire(%Group{}), do: :ok

  defp drop_web(type, id, gid) do
    StatusStorage.update_status(type, id, :sc_spiderweb, fn entry ->
      %{entry | state: Map.update!(entry.state, :groups, &(&1 -- [gid]))}
    end)
  end

  defp enemy?(%Group{} = group, {target_type, target_id}) do
    with {:ok, {_module, caster, _pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id),
         {:ok, {_module, target, _pid}} <- UnitRegistry.get_unit(target_type, target_id) do
      field_target?(group, caster, target)
    else
      _unavailable -> false
    end
  end

  defp field_target?(%Group{caster_type: :player} = group, caster, target),
    do: Targeting.validate_field_target(group, caster, target) == :ok

  defp field_target?(%Group{}, caster, target),
    do: Targeting.validate_enemy(caster, target) == :ok
end
