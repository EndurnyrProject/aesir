defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDisarm do
  @moduledoc """
  Disarm fires a bullet for 100% weapon damage. A landed hit the target
  survives rolls its rate in percent and, on success, strips the target's
  weapon for a flat 30 seconds unless Chemical Protection covers it. The
  skill's effect is shown either way and a failure is never reported. Renewal
  casts in 1600 ms plus 400 ms fixed with a one-second delay; pre-renewal is
  instant without a delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 513,
    name: :gs_disarm,
    display_name: "Disarm",
    max_level: 5,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    element: :weapon,
    require_weapon: [:revolver, :rifle],
    require_ammo: [:bullet],
    ammo_qty: List.duplicate(1, 5),
    sp_cost: Enum.map(1..5, &(10 + 5 * &1)),
    cast_time: [renewal: List.duplicate(1_600, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(400, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 5), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @duration_ms 30_000

  @typedoc "The unit numbers the rate reads: total primary stats and base level."
  @type unit_numbers :: %{
          :dex => integer(),
          :agi => integer(),
          :luk => integer(),
          :level => integer(),
          optional(atom()) => integer()
        }

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    with :ok <- strike(caster, target, level, definition), do: {:ok, caster}
  end

  @impl Active
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row),
    do: strike(caster, {type, id}, level, definition)

  @doc """
  The reference strip rate in percent, in its integer order:
  `dex / (4 * (7 - level)) + luk / (4 * (6 - level))`, then plus the caster's
  level, minus `target_agi * rate / 100`, the target's LUK and its level. It
  may be zero or negative, which always fails.
  """
  @spec rate(1..5, unit_numbers(), unit_numbers()) :: integer()
  def rate(level, caster, target) when level in 1..5 do
    base = div(caster.dex, 4 * (7 - level)) + div(caster.luk, 4 * (6 - level))
    base + caster.level - div(target.agi * base, 100) - target.luk - target.level
  end

  @doc "The strip's flat duration: no DEX or non-player bonus applies."
  @spec duration_ms() :: pos_integer()
  def duration_ms, do: @duration_ms

  defp strike(caster, target, level, definition) do
    case Combat.execute_skill_attack(caster, target,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: 100,
           skip_range: true,
           skip_crit: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true, target_survives?: true}} -> disarm(caster, target, level, definition)
      {:ok, _report} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp disarm(caster, target, level, definition) do
    with {:ok, pid, state, type} when type in [:player, :mob, :homunculus] <-
           TargetResolver.resolve(target) do
      input = %{rate: rate(level, numbers(caster), numbers(state)), duration_ms: @duration_ms}
      resolved = {target, pid, state, type}
      StripCommon.attempt(caster, resolved, level, definition, [:right_hand], :disarm, input)
    end

    :ok
  end

  defp numbers(unit) do
    stats = unit.__struct__.get_stats(unit)
    Map.put(stats.total_stats, :level, stats.base_level)
  end
end
