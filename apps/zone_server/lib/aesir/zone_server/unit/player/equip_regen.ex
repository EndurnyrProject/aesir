defmodule Aesir.ZoneServer.Unit.Player.EquipRegen do
  @moduledoc """
  Pure accumulation of the periodic HP/SP regen/loss granted by equipment
  (`bHPRegenRate`/`bHPLossRate`/`bSPRegenRate`/`bSPLossRate`).

  Each such bonus lives on the folded `modifiers.equipment` map as a
  `{family, interval_ms} => value` entry, where `family` is one of
  `:hp_regen_bonus`, `:hp_loss_bonus`, `:sp_regen_bonus`, `:sp_loss_bonus`. Per
  interval the wearer gains/loses `value` HP or SP; equal-interval contributions
  across items were already summed at fold time, so each entry fires as one
  accumulator.

  `compute/3` advances a per-entry elapsed-time accumulator by `elapsed_ms`,
  fires as many whole intervals as have elapsed (carrying the remainder), and
  returns the summed HP/SP gain and loss plus the updated accumulators. It
  applies no clamping — the caller knows the wearer's current and max HP/SP and
  applies loss before regen (HP loss cannot kill, regen cannot exceed max),
  matching the tick order of the natural-heal loop.

  Accumulators for entries no longer present (gear removed) are dropped, since
  only the entries currently on the equipment map are advanced.
  """

  @families %{
    hp_regen_bonus: :hp_gain,
    hp_loss_bonus: :hp_loss,
    sp_regen_bonus: :sp_gain,
    sp_loss_bonus: :sp_loss
  }

  @type accumulators :: %{{atom(), pos_integer()} => non_neg_integer()}
  @type deltas :: %{
          hp_gain: non_neg_integer(),
          hp_loss: non_neg_integer(),
          sp_gain: non_neg_integer(),
          sp_loss: non_neg_integer()
        }

  @doc """
  Advances the periodic HP/SP regen/loss accumulators by `elapsed_ms` and
  returns `{deltas, accumulators}`: a `t:deltas/0` map of the totals to
  gain/lose this tick and the updated accumulators (only for entries currently
  on `equip_modifiers`).

  When the wearer carries no periodic regen/loss gear the accumulators are `%{}`,
  letting the caller take a no-op fast path.
  """
  @spec compute(map(), accumulators(), non_neg_integer()) :: {deltas(), accumulators()}
  def compute(equip_modifiers, accumulators, elapsed_ms)
      when is_map(equip_modifiers) and is_map(accumulators) do
    zero = %{hp_gain: 0, hp_loss: 0, sp_gain: 0, sp_loss: 0}

    Enum.reduce(equip_modifiers, {zero, %{}}, fn entry, {deltas, acc} ->
      case periodic_entry(entry) do
        {bucket, key, interval, value} ->
          total = Map.get(accumulators, key, 0) + elapsed_ms
          amount = div(total, interval) * value
          {Map.update!(deltas, bucket, &(&1 + amount)), Map.put(acc, key, rem(total, interval))}

        :skip ->
          {deltas, acc}
      end
    end)
  end

  @spec periodic_entry({term(), term()}) ::
          {atom(), {atom(), pos_integer()}, pos_integer(), integer()} | :skip
  defp periodic_entry({{family, interval} = key, value})
       when is_integer(interval) and interval > 0 and is_integer(value) do
    case Map.fetch(@families, family) do
      {:ok, bucket} -> {bucket, key, interval, value}
      :error -> :skip
    end
  end

  defp periodic_entry(_entry), do: :skip
end
