defmodule Aesir.ZoneServer.Mmo.Combat.PotionRecovery do
  @moduledoc """
  Calculates the recipient-side recovery for a Potion Pitcher descriptor.

  Caster-side potion scaling is complete before this calculation. Recipient
  terms are normalized by the owning handler so player and Homunculus state
  remain outside the pure formula.
  """

  @typedoc "A Potion Pitcher recovery descriptor after caster-side scaling."
  @type descriptor :: {:potion, :hp | :sp, non_neg_integer()}

  @typedoc "Normalized target-side terms used by potion recovery."
  @type recipient_terms :: %{
          required(:learning_potion) => non_neg_integer(),
          required(:effective_vit) => integer(),
          required(:effective_int) => integer(),
          required(:item_heal_rate) => integer()
        }

  @doc "Returns target-side recovery with Renewal integer truncation."
  @spec recover(descriptor(), recipient_terms()) :: non_neg_integer()
  def recover(
        {:potion, :hp, caster_amount},
        %{
          learning_potion: learning_potion,
          effective_vit: effective_vit,
          item_heal_rate: item_heal_rate
        }
      ) do
    div(
      caster_amount *
        (100 + 5 * learning_potion + 2 * effective_vit + item_heal_rate),
      100
    )
  end

  def recover(
        {:potion, :sp, caster_amount},
        %{learning_potion: learning_potion, effective_int: effective_int}
      ) do
    div(caster_amount * (100 + 5 * learning_potion + 2 * effective_int), 100)
  end
end
