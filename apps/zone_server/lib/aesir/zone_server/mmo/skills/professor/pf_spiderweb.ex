defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSpiderweb do
  @moduledoc """
  Fiber Lock (PF_SPIDERWEB). Throws a web onto an enemy's cell up to 9 cells
  away for one Spiderweb. The web catches every living enemy of the caster
  standing on its cell when it lands (a Hiding unit is out of reach), in the
  map's block order: units other than monsters first, then monsters, the most
  recent to enter the cell's 8x8 block first. Nothing stepping or appearing onto
  the web is ever caught.

  Each catch is its own hold (`:sc_spiderweb`), 8 s (4 s on versus maps): a
  unit not yet held is rooted for it (pulled onto the web) and the web lives that
  long (3 s when the hold fails). A held unit takes the web into a free slot and
  its hold is restarted at the longer of what is left and the web's time: twice
  the base for the second catch of the hold in normal play, then the base again;
  on versus maps the base times the catch count, up to three. The web then lives
  that web time. A unit already in three web slots is immune and the web expires
  at once. The web keeps the last unit it caught: when the web goes, it frees its
  slot on that unit only, ending that unit's hold with its last slot. Every other
  caught unit stays held until its hold runs out or is burned. A web standing
  with no catch lives 16 s. Fire against a webbed unit is strengthened and burns
  one web at a time. A caster keeps at most three webs.

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
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active
  @behaviour Ground

  @max_webs 3
  @hold_ms 8_000
  @failed_catch_ms 3_000

  @typedoc "The web's tracked unit and expiry after its catches, `nil` when unchanged."
  @type catches :: {{atom(), integer()} | nil, integer() | nil}

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, term()}
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, %{position: cell}} <- Combat.resolve_combatant(target_id),
         :ok <- web(caster, level, cell) do
      {:ok, caster}
    end
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, term()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, _definition, _row) do
    with {:ok, %{position: cell}} <- Combat.resolve_combatant(type, id) do
      web(caster, level, cell)
    end
  end

  defp web(caster, level, cell) do
    with {:ok, group} <- Unit.place(caster, :pf_spiderweb, level, cell) do
      now = System.monotonic_time(:millisecond)
      {victim, expires_at} = catch_standing(group, caster.__struct__.to_combatant(caster), now)

      if victim, do: Unit.update_state(group.group_id, %{victim: victim})
      if expires_at, do: Manager.set_expires_at(group.group_id, expires_at)

      :ok
    end
  end

  @doc """
  Catches, at `now`, every unit standing on the newly placed web's cell that
  the web reaches: living enemies of `caster`, not Hiding, in the map's block
  order (`SpatialIndex.units_in_cell/3`).

  Returns the unit the web keeps (the last one caught) and its new expiry, the
  last catch's: `now` plus that unit's web time, or `now` itself for a unit
  already in three web slots. `nil` leaves either unchanged.
  """
  @spec catch_standing(Group.t(), Combatant.t(), integer()) :: catches()
  def catch_standing(%Group{map_name: map_name, center: {x, y}} = group, caster, now) do
    map_name
    |> SpatialIndex.units_in_cell(x, y)
    |> SplashTargets.eligible(caster)
    |> Enum.filter(&Targeting.placement_reaches?(group.skill_id, &1))
    |> Enum.reduce({nil, nil}, fn ref, {victim, _expires_at} ->
      case capture(group, ref, now) do
        :immune -> {victim, now}
        {:caught, web_ms} -> {ref, now + web_ms}
      end
    end)
  end

  @doc """
  Catches `ref` in `group`'s web at `now`. Returns `{:caught, web_ms}`, how long
  the web lives from `now` (the hold it applied on a first catch, 3 s when that
  fails, the stacked web time otherwise), or `:immune` for a unit already in
  three web slots. The catch is stored only over the hold it read, reading it
  again after a concurrent change.
  """
  @spec capture(Group.t(), {atom(), integer()}, integer()) ::
          {:caught, non_neg_integer()} | :immune
  def capture(%Group{} = group, {type, id} = ref, now) do
    versus? = Targeting.versus_map?(group.map_name)
    base_ms = if versus?, do: div(@hold_ms, 2), else: @hold_ms

    case StatusStorage.get_status(type, id, :sc_spiderweb) do
      %StatusEntry{state: %{slots: slots}} = entry ->
        if Enum.all?(slots),
          do: :immune,
          else: catch_held(group, ref, entry, now, base_ms * stack_factor(entry.val1, versus?))

      nil ->
        case first_hold(group, ref, base_ms) do
          :held_meanwhile -> capture(group, ref, now)
          web_ms -> {:caught, web_ms}
        end
    end
  end

  defp catch_held(group, ref, entry, now, web_ms) do
    slots = take_slot(entry.state.slots, group.group_id)

    if extend_hold(ref, entry, slots, web_ms, now),
      do: {:caught, web_ms},
      else: capture(group, ref, now)
  end

  # Normal play: the second catch of a hold doubles the base, later ones keep
  # it. Versus maps multiply the base by the catch count, up to three.
  defp stack_factor(caught, true) when caught < 3, do: caught + 1
  defp stack_factor(caught, false) when caught < 2, do: caught + 1
  defp stack_factor(_caught, _versus?), do: 1

  defp take_slot(slots, group_id) do
    index = Enum.find_index(slots, &is_nil/1)
    List.replace_at(slots, index, group_id)
  end

  # Restarts the hold, one catch more, at the longer of what is left and the web
  # time. A hold without a deadline only takes the web into its slot.
  defp extend_hold({type, id}, %StatusEntry{expires_at: expires_at} = entry, slots, web_ms, now)
       when is_integer(expires_at) do
    restarted = %{
      entry
      | val1: entry.val1 + 1,
        started_at: now,
        expires_at: now + max(expires_at - now, web_ms),
        state: %{entry.state | slots: slots}
    }

    StatusInterpreter.restart_status_if_current(type, id, :sc_spiderweb, entry, restarted)
  end

  defp extend_hold({type, id}, entry, slots, _web_ms, _now) do
    StatusStorage.replace_status_if_current(type, id, :sc_spiderweb, entry, %{
      entry
      | state: %{entry.state | slots: slots}
    })
  end

  # A first hold never replaces one another web started meanwhile (the
  # status refuses to overlap itself); that unit is caught again as held. Only
  # this catch writes its web into a slot, so a hold carrying it is the one
  # this catch started, even if another web restarted it since. The status has
  # no resistance, so a started hold lasts exactly the base time.
  defp first_hold(%Group{group_id: gid, center: {x, y}} = group, {type, id}, base_ms) do
    applied =
      StatusInterpreter.apply_status(type, id, :sc_spiderweb,
        val1: 1,
        duration: base_ms,
        caster_id: group.caster_id,
        source_type: group.caster_type,
        state: %{slots: [gid, nil, nil]}
      )

    case {applied, StatusStorage.get_status(type, id, :sc_spiderweb)} do
      {_applied, %StatusEntry{state: %{slots: slots}}} ->
        if gid in slots do
          Knockback.pull_to(type, id, x, y)
          base_ms
        else
          :held_meanwhile
        end

      {:ok, nil} ->
        Knockback.pull_to(type, id, x, y)
        base_ms

      {_failed, nil} ->
        @failed_catch_ms
    end
  end

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

  @doc """
  The web going: frees its slot on the unit it kept, ending that unit's hold
  when no other slot holds a web. A unit no longer holding it in a slot is left
  alone.
  """
  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{group_id: gid, state: %{victim: {type, id}}}) do
    release(type, id, gid)
  end

  def on_expire(%Group{}), do: :ok

  # Frees the web's slot over the hold it read, ending the hold with its last
  # slot; a concurrent change reads the hold again.
  defp release(type, id, gid) do
    with %StatusEntry{state: %{slots: slots}} = entry <-
           StatusStorage.get_status(type, id, :sc_spiderweb),
         index when is_integer(index) <- Enum.find_index(slots, &(&1 == gid)) do
      left = List.replace_at(slots, index, nil)

      released? =
        if Enum.all?(left, &is_nil/1),
          do: StatusInterpreter.remove_status_if_current(type, id, :sc_spiderweb, entry),
          else:
            StatusStorage.replace_status_if_current(type, id, :sc_spiderweb, entry, %{
              entry
              | state: %{entry.state | slots: left}
            })

      unless released?, do: release(type, id, gid)
    end

    :ok
  end
end
