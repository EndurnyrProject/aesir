defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon do
  @moduledoc false

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @base_durations [75_000, 90_000, 105_000, 120_000, 135_000]

  @spec cast(
          struct(),
          {:unit, integer() | {atom(), integer()}},
          pos_integer(),
          map(),
          atom(),
          atom(),
          non_neg_integer()
        ) :: {:ok, struct()} | {:error, atom()}
  def cast(caster, {:unit, target_ref}, level, _definition, slot, status_id, val2) do
    with {:ok, target_pid, target, target_type} <- TargetResolver.resolve(target_ref) do
      caster_dex = unit_stats(caster).dex
      target_dex = unit_stats(target).dex

      if __MODULE__.roll_success?(level, caster_dex, target_dex) do
        duration = strip_duration_ms(level, caster_dex, target_dex, target_type)

        opts = [
          duration: duration,
          val2: val2,
          caster_id: unit_id(caster),
          source_type: unit_type(caster)
        ]

        apply_strip(target_type, target_pid, target, slot, status_id, opts)
      end

      {:ok, caster}
    end
  end

  @spec strip_success_rate(pos_integer(), integer(), integer()) :: 0..1000
  def strip_success_rate(level, caster_dex, target_dex) do
    (50 * (level + 1) + 2 * (caster_dex - target_dex))
    |> max(0)
    |> min(1_000)
  end

  @spec strip_duration_ms(pos_integer(), integer(), integer(), :player | :mob) :: pos_integer()
  def strip_duration_ms(level, caster_dex, target_dex, target_type)
      when target_type in [:player, :mob] do
    bonus = max(1, level + 500 * (caster_dex - target_dex))
    Enum.at(@base_durations, level - 1) + bonus + if(target_type == :mob, do: 15_000, else: 0)
  end

  @spec roll_success?(pos_integer(), integer(), integer()) :: boolean()
  def roll_success?(level, caster_dex, target_dex) do
    :rand.uniform(1_000) <= strip_success_rate(level, caster_dex, target_dex)
  end

  defp apply_strip(:player, target_pid, _target, slot, _status_id, opts),
    do: PlayerSession.strip_equip(target_pid, slot, opts)

  defp apply_strip(:mob, _target_pid, target, _slot, status_id, opts) do
    # Skill success already rolled; don't re-roll debuff resistance on apply.
    StatusInterpreter.apply_status(
      :mob,
      unit_id(target),
      status_id,
      Keyword.put(opts, :bypass_resistance, true)
    )
  end

  defp unit_stats(unit), do: unit.__struct__.get_stats(unit)
  defp unit_id(unit), do: unit.__struct__.get_unit_id(unit)
  defp unit_type(unit), do: unit.__struct__.get_unit_type(unit)
end
