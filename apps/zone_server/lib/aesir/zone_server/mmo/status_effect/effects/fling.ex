defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fling do
  @moduledoc """
  Fling (SC_FLING).

  `val1` is the coins thrown. The holder loses 5% soft DEF per coin (val3); a
  non-player also loses 5% hard DEF per coin (val2), a player none.

  Renewal and pre-renewal agree; it lasts 30 s.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fling,
    no_dispel: false,
    no_clear_buff: false,
    calc_flags: [:def, :def2]

  @impl true
  def modifiers(instance, _context), do: %{def_rate: -instance.val2, def2_rate: -instance.val3}

  @impl true
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, instance, context) do
    hard = if Map.get(context, :unit_type) == :player, do: 0, else: 5 * instance.val1
    {:ok, %{instance | val2: hard, val3: 5 * instance.val1}}
  end
end
