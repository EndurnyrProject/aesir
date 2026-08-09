defmodule Aesir.ZoneServer.Unit.Player.EquipRegen do
  @moduledoc """
  Pure accumulation of the periodic HP regen/loss granted by equipment
  (`bHPRegenRate,n,t` and `bHPLossRate,n,t`).

  Each such bonus lives on the folded `modifiers.equipment` map as a
  `{family, interval_ms} => value` entry, where `family` is `:hp_regen_bonus`
  (gain) or `:hp_loss_bonus` (loss). Per interval the wearer gains/loses `value`
  HP; equal-interval contributions across items were already summed at fold
  time, so each entry fires as one accumulator.

  `compute/3` advances a per-entry elapsed-time accumulator by `elapsed_ms`,
  fires as many whole intervals as have elapsed (carrying the remainder), and
  returns the summed gain and loss plus the updated accumulators. It applies no
  clamping — the caller knows the wearer's current and max HP and applies loss
  before regen (loss cannot kill, regen cannot exceed max), matching the tick
  order of the natural-heal loop.

  Accumulators for entries no longer present (gear removed) are dropped, since
  only the entries currently on the equipment map are advanced.
  """

  @regen_family :hp_regen_bonus
  @loss_family :hp_loss_bonus

  @type accumulators :: %{{atom(), pos_integer()} => non_neg_integer()}

  @doc """
  Advances the periodic HP-regen/loss accumulators by `elapsed_ms` and returns
  `{gain, loss, accumulators}`: the total HP to gain from `:hp_regen_bonus`
  entries, the total HP to lose from `:hp_loss_bonus` entries, and the updated
  accumulators (only for entries currently on `equip_modifiers`).

  When the wearer carries no periodic HP-regen/loss gear the result is
  `{0, 0, %{}}`, letting the caller take a no-op fast path.
  """
  @spec compute(map(), accumulators(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer(), accumulators()}
  def compute(equip_modifiers, accumulators, elapsed_ms)
      when is_map(equip_modifiers) and is_map(accumulators) do
    equip_modifiers
    |> Enum.reduce({0, 0, %{}}, fn
      {{family, interval} = key, value}, {gain, loss, acc}
      when family in [@regen_family, @loss_family] and is_integer(interval) and interval > 0 and
             is_integer(value) ->
        total = Map.get(accumulators, key, 0) + elapsed_ms
        amount = div(total, interval) * value
        acc = Map.put(acc, key, rem(total, interval))

        case family do
          @regen_family -> {gain + amount, loss, acc}
          @loss_family -> {gain, loss + amount, acc}
        end

      _entry, result ->
        result
    end)
  end
end
