defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfFogwall do
  @moduledoc """
  Blinding Mist (PF_FOGWALL). A 5x3 fog lasting 20 s (40 s over a Deluge), at
  most two per caster, that cannot be raised over a Volcano or Violent Gale.

  Everyone inside holds `:sc_fogwall`: skill damage taken -25%, normal ranged
  damage taken -75%, and normal ranged attacks against them lose 50 hit rate.
  An enemy stepping in is blinded for 10 s unless it stands in a Deluge; a
  player's Blind ends when they step out.

  Identical in both modes: 25 SP, 9 cells.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 404,
    name: :pf_fogwall,
    requires: [],
    display_name: "Blinding Mist",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :earth,
    range: 9,
    sp_cost: List.duplicate(25, 5),
    unit_duration: List.duplicate(20_000, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @blind_ms 10_000

  @doc "Refuses a fog that would overlap a Volcano or Violent Gale."
  @spec validate(map(), term(), pos_integer(), Definition.t()) ::
          :ok | {:error, :blocked_by_field}
  def validate(%{map_name: map}, {:ground, x, y}, _level, _definition) do
    if overlaps?(map, cells({x, y}), [:sa_volcano, :sa_violentgale]),
      do: {:error, :blocked_by_field},
      else: :ok
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, map_name: map, level: level}) do
    cells = cells(center)
    base = Enum.at(definition().unit_duration, level - 1)

    {:ok,
     %{
       cells: cells,
       state: %{},
       interval: 1_000,
       duration: if(overlaps?(map, cells, [:sa_deluge]), do: base * 2, else: base),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 2}
     }}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{}),
    do: %{status_type: :sc_fogwall, params: [], target?: fn _unit -> true end}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_touch(%Group{} = group, {type, id} = mover) do
    if enemy?(group, mover) and not StatusStorage.has_status?(type, id, :sc_deluge) do
      StatusInterpreter.apply_status(type, id, :sc_blind,
        duration: @blind_ms,
        caster_id: group.caster_id,
        source_type: group.caster_type
      )
    end

    {:ok, group}
  end

  @impl Ground
  @spec on_out(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_out(%Group{} = group, {:player, id}) do
    StatusInterpreter.remove_status(:player, id, :sc_blind)
    {:ok, group}
  end

  def on_out(%Group{} = group, _mover), do: {:ok, group}

  defp cells({cx, cy}), do: for(dx <- -2..2, dy <- -1..1, do: {cx + dx, cy + dy})

  defp overlaps?(map, cells, skill_names) do
    Enum.any?(cells, fn {x, y} ->
      map |> Storage.get_groups_at_cell(x, y) |> Enum.any?(&(&1.skill_name in skill_names))
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
