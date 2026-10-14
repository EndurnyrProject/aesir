defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap do
  @moduledoc """
  Skid Trap (HT_SKIDTRAP).

  The first enemy within one cell sets it off and slides 5 plus level cells
  away from where its caster stood when placing it (west when standing on that
  very cell), unless it resists being knocked back. Renewal then holds it in
  place (Stop) for 3 s; bosses and status-immune monsters never set it off.
  Pre-renewal has no hold: a monster that sets it off forgets its target
  instead, and bosses set it off too.

  Otherwise the modes agree: lasting 300 s down to 60 s, for 10 SP and one
  trap.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 115,
    name: :ht_skidtrap,
    requires: [],
    display_name: "Skid Trap",
    max_level: 5,
    target_type: :ground,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [300_000, 240_000, 180_000, 120_000, 60_000],
    sp_cost: [10, 10, 10, 10, 10],
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @stop_ms 3_000

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(
        %Group{center: center, level: level, caster_type: caster_type, caster_id: caster_id} =
          group
      ) do
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(caster_type, caster_id)
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1,
       visibility: Trap.visibility(:ht_skidtrap)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs) do
    refs = Trap.unit_targets(group, refs)

    case GameMode.mode() do
      :renewal -> Enum.reject(refs, &Trap.status_immune?/1)
      :pre_renewal -> refs
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, now) do
    with true <- Trap.armed?(group),
         {:ok, _caster} <- Trap.resolve_caster(group) do
      skid(group, target)
      {:ok, Trap.spring(group, now)}
    else
      _inert -> {:ok, group}
    end
  end

  defp skid(%Group{} = group, {type, id} = target) do
    {from_x, from_y} = group.origin || group.center
    Knockback.knockback(type, id, from_x, from_y, group.level + 5)
    after_skid(GameMode.mode(), group, target)
  end

  defp after_skid(:renewal, group, {type, id}) do
    StatusInterpreter.apply_status(type, id, :sc_stop,
      duration: @stop_ms,
      bypass_resistance: true,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end

  defp after_skid(:pre_renewal, _group, {:mob, id}) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_module, _state, pid}} -> MobSession.set_target(pid, nil)
      _gone -> :ok
    end
  end

  defp after_skid(:pre_renewal, _group, _target), do: :ok
end
