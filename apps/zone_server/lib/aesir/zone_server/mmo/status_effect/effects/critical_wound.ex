defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CriticalWound do
  @moduledoc """
  Critical Wound reduces healing skills, item healing and thrown potions.

  Levels repeat their strength every five ranks: ranks 6 through 10 retain
  their supplied lifetime but use ranks 1 through 5's 20% to 100% penalty.
  The initialized penalty lives in `val2`; restored statuses retain it.

  Both modes share the status. Healing consumers apply their own mode-specific
  rounding; plain script heals, percentage heals and natural regeneration are
  unaffected. Death and debuff clearing remove it, but Dispel does not.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_criticalwound,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    properties: [:debuff],
    icon: :criticalwound

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), Definition.context()) ::
          Definition.hook_result()
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, instance, _context) do
    level = 1 + rem(instance.val1 - 1, 5)
    {:ok, %{instance | val1: level, val2: 20 * level}}
  end
end
