defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpBasilica do
  @moduledoc """
  Basilica (HP_BASILICA). Two different mechanics behind one skill.

  Renewal: a self buff (`sc_basilica_buff`) for 60 to 180 s: weapon attacks
  deal `5 * level` percent more to Dark and Undead targets and Holy spells gain
  `3 * level` percent. 3 s cast plus 1 s fixed, 1 s after-cast delay, 30 s
  cooldown, 40 to 80 SP, no catalysts.

  Pre-renewal: a 5x5 sanctuary placed on the caster for 20 to 40 s; its holders
  carry `sc_basilica`: shielded from all non-boss damage, unable to attack or
  cast. Each cell is a unit acting every 300 ms on the unit pass: an enemy of
  the caster standing on it is pushed 2 cells backwards (a boss cannot be
  pushed and stays, still able to act); any other unit but the caster that
  does not hold `sc_basilica` receives it for the sanctuary's full lifetime and
  keeps it after leaving. A player also receives it, enemy or not, on any step
  or warp onto a sanctuary cell (indefinitely), and loses it on any step or warp
  onto another cell (`StatusEffect.Effects.Basilica.sync_cell_status/1`). A
  cell that ends takes the status from every unit standing on it. Song
  statuses are not granted on its cells. The caster carries `sc_basilica_caster`: rooted, shielded the same way, not knocked
  back by non-boss sources, and only able to recast Basilica, which ends the
  field instantly with no SP or catalysts but with the after-cast delay
  (creating it has none). Casting costs 80 to 120 SP plus a Yellow, Red, and
  Blue Gemstone and a Holy Water, takes 5 to 9 s, and needs a 7x7 area free of
  walls and of other players and monsters, off Land Protector. The field ends
  on expiry, cancel, map change, or the caster's death.

  Accepted deviation: the 7x7 checks also run at cast completion, so a monster
  wandering in during the cast fizzles it (the reference checks only when the
  cast begins).

  Player-only in both modes; no monster row casts it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 362,
    name: :hp_basilica,
    ranged_single_unit: [renewal: false, pre_renewal: true],
    requires: [],
    display_name: "Basilica",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    knockback: [renewal: 0, pre_renewal: 2],
    sp_cost: [renewal: [40, 50, 60, 70, 80], pre_renewal: [80, 90, 100, 110, 120]],
    cast_time: [
      renewal: List.duplicate(3_000, 5),
      pre_renewal: [5_000, 6_000, 7_000, 8_000, 9_000]
    ],
    fixed_cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 5),
      pre_renewal: [2_000, 3_000, 4_000, 5_000, 6_000]
    ],
    cooldown: [renewal: List.duplicate(30_000, 5), pre_renewal: []],
    duration: [
      renewal: [60_000, 90_000, 120_000, 150_000, 180_000],
      pre_renewal: [20_000, 25_000, 30_000, 35_000, 40_000]
    ],
    item_cost: [
      renewal: [],
      pre_renewal: [
        %{id: 715, amount: 1},
        %{id: 716, amount: 1},
        %{id: 717, amount: 1},
        %{id: 523, amount: 1}
      ]
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit, as: AesirUnit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground

  @interval 300
  @field_radius 2
  @clear_radius 3

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :blocked_area | :land_protector}
  def validate(%PlayerState{character_id: id} = caster, _target, _level, _definition) do
    cond do
      GameMode.mode() == :renewal or anchored?(id) -> :ok
      not clear_area?(caster) -> {:error, :blocked_area}
      true -> :ok
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%MobState{}, _target, _level, _definition), do: {:error, :player_only}

  def cast(%PlayerState{character_id: id} = caster, _target, level, definition) do
    case GameMode.mode() do
      :renewal ->
        bless_self(caster, level, definition)

      :pre_renewal ->
        if anchored?(id) do
          StatusInterpreter.remove_status(:player, id, :sc_basilica_caster)
          {:ok, caster}
        else
          raise_sanctuary(caster, level, definition)
        end
    end
  end

  @doc "Recasting to end the sanctuary spends no SP; creating one costs the listed SP."
  @impl Active
  @spec dynamic_cost(Active.caster(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(caster, _target, level, definition) do
    sp = if pre_renewal_anchored?(caster), do: 0, else: Cost.resolve_sp(caster, definition, level)
    Cost.from_definition(caster, definition, level, sp: sp)
  end

  @doc "Recasting to end the sanctuary needs no catalysts."
  @impl Active
  @spec dynamic_item_cost(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          [map()]
  def dynamic_item_cost(caster, _target, _level, definition),
    do: if(pre_renewal_anchored?(caster), do: [], else: definition.item_cost)

  @doc "Recasting to end the sanctuary is instant."
  @impl Active
  @spec dynamic_cast_time(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          %{cast_time: non_neg_integer(), fixed_cast_time: non_neg_integer()}
  def dynamic_cast_time(caster, _target, level, definition) do
    if pre_renewal_anchored?(caster) do
      %{cast_time: 0, fixed_cast_time: 0}
    else
      %{
        cast_time: Enum.at(definition.cast_time, level - 1, 0),
        fixed_cast_time: Enum.at(definition.fixed_cast_time, level - 1, 0)
      }
    end
  end

  @doc "Pre-renewal: creating the sanctuary has no after-cast delay; ending it does."
  @impl Active
  @spec dynamic_after_cast_delay(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          non_neg_integer()
  def dynamic_after_cast_delay(caster, _target, level, definition) do
    table = Enum.at(definition.after_cast_delay, level - 1, 0)

    cond do
      GameMode.mode() == :renewal -> table
      pre_renewal_anchored?(caster) -> table
      true -> 0
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    {:ok,
     %{
       cells: Layout.square(center, @field_radius),
       state: %{basilica: true},
       interval: @interval,
       duration: duration(level),
       unit_range: 0
     }}
  end

  # A sanctuary whose caster is gone ends.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{caster_type: caster_type, caster_id: caster_id} = group, _now) do
    case UnitRegistry.get_unit(caster_type, caster_id) do
      {:ok, _caster} -> {:ok, group}
      _gone -> {:expire, group}
    end
  end

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [Ref.t()]) :: [Ref.t()]
  def unit_targets(%Group{caster_type: type, caster_id: id}, _cell, refs),
    do: Enum.filter(refs, &(&1 != {type, id} and living?(&1)))

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), Ref.t(), integer()) :: {:ok, Group.t()}
  def on_unit_hit(
        %Group{caster_type: caster_type, caster_id: caster_id} = group,
        _cell,
        ref,
        _now
      ) do
    with {:ok, {_module, caster_state, _pid}} <- UnitRegistry.get_unit(caster_type, caster_id),
         {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(elem(ref, 0), elem(ref, 1)) do
      if Targeting.validate_enemy(caster_state, state) == :ok,
        do: push_out({ref, state}),
        else: shelter(group, ref)
    end

    {:ok, group}
  end

  # A cell that ends takes the status from the units standing on it. Units
  # stepping off never trigger this: the sanctuary acts on its own timer.
  @impl Ground
  @spec on_out(Group.t(), Ref.t()) :: {:ok, Group.t()}
  def on_out(%Group{} = group, {type, id}) do
    if StatusStorage.has_status?(type, id, :sc_basilica),
      do: StatusInterpreter.remove_status(type, id, :sc_basilica, owner_refresh: :notify)

    {:ok, group}
  end

  # A non-enemy without the status receives it for the sanctuary's full
  # lifetime, counted from now.
  defp shelter(%Group{} = group, {type, id}) do
    unless StatusStorage.has_status?(type, id, :sc_basilica) do
      StatusInterpreter.apply_status(type, id, :sc_basilica,
        val1: 0,
        val3: group.group_id,
        val4: group.caster_id,
        duration: group.expires_at - group.created_at,
        caster_id: group.caster_id,
        source_type: group.caster_type
      )
    end

    :ok
  end

  defp living?({type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, _pid}} -> AesirUnit.living?(state)
      _gone -> false
    end
  end

  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{caster_id: caster_id}) do
    StatusInterpreter.remove_status(:player, caster_id, :sc_basilica_caster,
      owner_refresh: :notify
    )

    :ok
  end

  defp bless_self(%PlayerState{character_id: id} = caster, level, definition) do
    case StatusInterpreter.apply_status(:player, id, :sc_basilica_buff,
           val1: level,
           caster_id: id,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp raise_sanctuary(%PlayerState{x: x, y: y} = caster, level, definition) do
    # The reference refuses a Land Protector centre inside the implementation
    # and sets `SKILL_NOCONSUME_REQ`: the failure is reported and the items are
    # spared.
    if Storage.land_protected?(caster.map_name, x, y) do
      {:failed, caster, :land_protector, :spare_items}
    else
      place_sanctuary(caster, level, definition, {x, y})
    end
  end

  defp place_sanctuary(caster, level, definition, cell) do
    case Unit.place(caster, :hp_basilica, level, cell) do
      {:ok, group} ->
        lock(caster, level, group, definition)

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  defp lock(
         %PlayerState{character_id: id} = caster,
         level,
         %Group{group_id: group_id},
         definition
       ) do
    params = [
      val1: level,
      val2: group_id,
      duration: Enum.at(definition.duration, level - 1),
      caster_id: id
    ]

    case StatusInterpreter.apply_status(:player, id, :sc_basilica_caster, params) do
      :ok ->
        {:ok, caster}

      {:error, _reason} = error ->
        Unit.destroy_async(group_id)
        error
    end
  end

  defp anchored?(id), do: StatusStorage.has_status?(:player, id, :sc_basilica_caster)

  defp pre_renewal_anchored?(%PlayerState{character_id: id}),
    do: GameMode.mode() == :pre_renewal and anchored?(id)

  defp pre_renewal_anchored?(_caster), do: false

  defp duration(level), do: Enum.at(definition().duration, level - 1)

  defp clear_area?(%PlayerState{character_id: id, map_name: map_name, x: x, y: y}) do
    no_walls?(map_name, x, y) and no_other_units?(map_name, x, y, id)
  end

  defp no_walls?(map_name, x, y) do
    case MapCache.get(map_name) do
      {:ok, map} ->
        {x, y}
        |> Layout.square(@clear_radius)
        |> Enum.all?(fn {cx, cy} -> not MapData.check_cell(map, cx, cy, :chk_wall) end)

      _missing ->
        false
    end
  end

  # A square area, not the Manhattan range query, so the 7x7 corners count.
  defp no_other_units?(map_name, x, y, caster_id) do
    {x1, y1} = {x - @clear_radius, y - @clear_radius}
    {x2, y2} = {x + @clear_radius, y + @clear_radius}

    SpatialIndex.get_units_in_area(:mob, map_name, x1, y1, x2, y2) == [] and
      SpatialIndex.get_units_in_area(:player, map_name, x1, y1, x2, y2) -- [caster_id] == []
  end

  # Pushed directly backwards: the push origin sits one cell ahead of the
  # unit's facing, so the blow travels opposite its facing.
  defp push_out({{type, id}, state}) do
    {dx, dy} = Geometry.facing_delta(Map.get(state, :dir, 0))
    Knockback.knockback(type, id, state.x + dx, state.y + dy, 2)
  end
end
