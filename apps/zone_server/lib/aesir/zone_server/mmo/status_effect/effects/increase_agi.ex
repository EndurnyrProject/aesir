defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi do
  @moduledoc """
  Increase AGI (SC_INCREASEAGI).

  In both modes raises AGI by 2 + skill level, with a flat 25% movement
  haste regardless of level. Renewal additionally contributes skill level to
  the direct ASPD bonus; pre-renewal receives only AGI's normal ASPD effect.
  `haste_rate` keeps only the strongest active haste buff.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increaseagi,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [renewal: [:agi, :speed, :aspd], pre_renewal: [:agi, :speed]],
    flags: [:failed_mado],
    end_on_start: [:sc_decreaseagi, :sc_adoramus],
    conflicts_with: [:sc_quagmire],
    icon: :inc_agi

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    %{
      agi: instance.val2,
      haste_rate: 25,
      aspd: if(GameMode.mode() == :renewal, do: instance.val1, else: 0)
    }
  end

  @impl true
  def before_overlap(target, _instance, _context),
    do: {:continue, high_spirit_end_actions(target)}

  @impl true
  def on_apply(_target, instance, %{loaded: false}),
    do: {:ok, %{instance | val2: 2 + instance.val1}}

  def on_apply(_target, instance, _context), do: {:ok, instance}
end
