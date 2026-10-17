defmodule Aesir.ZoneServer.Mmo.Skill.Ground.Trigger do
  @moduledoc """
  Movement-pipeline hook that fires ground skill-unit `on_touch`/`on_out`
  callbacks.

  Invoked from the single `Aesir.ZoneServer.Unit.Movement.set_position/4`
  chokepoint after a unit's cell changes, so both player and mob movers
  trigger ground units (Warp Portal, Pneuma). Timer units (`timer_unit?/1`:
  traps, Fire Pillar, Storm Gust, ...) act only on the skill-unit timer, never
  on a step, an arrival or a removal. `on_step/7` runs the
  whole step as one manager pass (`Manager.step/3`): the old cell's groups
  leave the mover, the new cell's groups place it (`on_touch/2`), and the
  fields the mover is no longer placed on end their statuses; `on_out/2` fires
  once per footprint the mover stepped off entirely (moving between cells of
  the same footprint does not count). `on_appear/4` places a unit that appears
  on a cell without stepping onto it (a mob spawn, a homunculus call);
  `on_removed/1` runs the leave events of every group on the cell of a unit
  removed from play (a warp, a logout, a despawn, a vaporize, a death). A
  dissonant song cell leaves an appearing or removed unit whether or not it
  targets it. Spider Web never acts on an arrival, by a step or an appearance:
  it catches only the units standing on its cell when it is placed. All only invoke modules that export the matching
  callback, and apply its result:

    - `{:ok, updated_group}` - the updated group is persisted.
    - `:expire` - the group is torn down with the manager's normal cleanup.

  The callback itself decides hostility (owner/ally exclusion); this trigger only
  invokes it for every mover and applies the result.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @typedoc "The unit that entered the cell: `{unit_type, unit_id}`."
  @type mover :: {atom(), integer()}

  # Ground units with an interval and no DualMode flag (Lullaby aside) act on
  # their own timer, never on a unit's step, appearance or removal. Hunter traps
  # carry trap state. Gravitation has DualMode only in classic.
  @timer_units [
    :mg_firewall,
    :mg_thunderstorm,
    :pr_sanctuary,
    :pr_magnus,
    :wz_firepillar,
    :wz_meteor,
    :wz_vermilion,
    :wz_icewall,
    :wz_stormgust,
    :ht_skidtrap,
    :ht_landmine,
    :ht_anklesnare,
    :ht_shockwave,
    :ht_sandman,
    :ht_flasher,
    :ht_freezingtrap,
    :ht_blastmine,
    :ht_claymoretrap,
    :ht_talkiebox,
    :as_venomdust,
    :am_demonstration,
    :cr_grandcross,
    :pa_gospel,
    :npc_earthquake,
    :npc_evilland,
    :hp_basilica,
    :ba_dissonance,
    :dc_uglydance
  ]

  @doc """
  Runs a step from `(old_x, old_y)` on `old_map` to `(new_x, new_y)` on
  `new_map` as one manager pass. Returns `:ok`; a step between two bare cells
  costs two cell lookups.
  """
  @spec on_step(mover(), String.t(), integer(), integer(), String.t(), integer(), integer()) ::
          :ok
  def on_step(mover, old_map, old_x, old_y, new_map, new_x, new_y),
    do: Manager.step(mover, {old_map, old_x, old_y}, {new_map, new_x, new_y})

  @doc """
  Whether a ground unit acts only on its own timer: an interval and no
  DualMode (Lullaby aside), and every armed or spent trap. Such a unit never
  acts on a unit's appearance or removal.
  """
  @spec timer_unit?(Group.t()) :: boolean()
  def timer_unit?(%Group{state: %{trap: %TrapState{}}}), do: true
  def timer_unit?(%Group{skill_name: :hw_gravitation}), do: GameMode.mode() == :renewal
  def timer_unit?(%Group{skill_name: skill_name}), do: skill_name in @timer_units

  @doc "Whether a ground unit acts on a unit arriving on its cell, by a step or an appearance (Spider Web never does)."
  @spec acts_on_appearance?(Group.t()) :: boolean()
  def acts_on_appearance?(%Group{skill_name: skill_name}), do: skill_name != :pf_spiderweb

  @doc """
  Places a unit appearing on `(x, y)` without stepping onto it, as one manager
  pass (`Manager.appear/2`): a dissonant song cell leaves it, Spider Web and
  timer units do nothing, every other unit places it. Returns `:ok`.
  """
  @spec on_appear(mover(), String.t(), integer(), integer()) :: :ok
  def on_appear(mover, map_name, x, y), do: Manager.appear(mover, {map_name, x, y})

  @doc """
  Runs the leave events of every ground unit covering the mover's cell when it
  is removed from play, as one manager pass (`Manager.remove/2`): a map
  removal (call it before the mover leaves the spatial index) or a death, with
  no step bookkeeping. A dissonant song cell leaves it, timer units do
  nothing, every other unit runs `on_out`, then the field's `onleft`. A unit
  without an indexed position runs nothing. Returns `:ok`.
  """
  @spec on_removed(mover()) :: :ok
  def on_removed({unit_type, unit_id} = mover) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} -> Manager.remove(mover, {map_name, x, y})
      {:error, _not_placed} -> :ok
    end
  end

  @doc """
  Recenters every group anchored to the mover (a pre-renewal song or dance
  field) on the mover's cell `(x, y)` on `map_name`.

  Units without an anchored group cost one caster-index lookup. Returns `:ok`.
  """
  @spec on_caster_moved(mover(), String.t(), integer(), integer()) :: :ok
  def on_caster_moved({unit_type, unit_id}, map_name, x, y) do
    unit_type
    |> Storage.get_groups_by_caster(unit_id)
    |> Enum.filter(&Group.follows_caster?/1)
    |> Enum.each(&Manager.follow_caster(&1.group_id, map_name, {x, y}))
  end
end
