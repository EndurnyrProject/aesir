defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StoneWait do
  @moduledoc """
  Petrifying (SC_STONEWAIT), the wait before a petrification sets in.

  The holder cannot attack or use skills but can still move, and its defenses are
  unchanged. Every petrification starts here: the applier passes the whole
  petrification duration and, in `state: %{delay: ms}`, the length of the wait
  (100 ms unless given, the start delay of equipment and Tarot petrification; Stone
  Curse waits its own first duration). The wait lasts exactly that delay, and the
  resistance-adjusted rest, at least 1 ms, is kept in `val3` as the Stone duration.

  Only when the wait runs out does Stone start, unavoidably and without another
  resistance roll; a cure or any other removal ends the petrification here.
  Applying it while the target is already petrifying or petrified ends both
  instead.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stonewait,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :prevents_skills, :prevents_attack],
    prevented_by: [
      renewal: [:sc_whiteimprison, :sc_freeze, :sc_stun, :sc_sleep, :sc_burning],
      pre_renewal: [:sc_freeze, :sc_stun, :sc_sleep, :sc_burning]
    ],
    end_return: [:sc_stonewait, :sc_stone],
    immunity: [:boss, :undead],
    duration: [renewal: 17_000, pre_renewal: 20_000],
    opt1: :stonewait

  @default_delay_ms 100

  @impl true
  def resolve_duration(instance, duration) do
    delay = Map.get(instance.state || %{}, :delay, @default_delay_ms)
    {delay, %{instance | val3: max(1, duration - delay)}}
  end

  @impl true
  def on_timeout(_target, instance, _context) do
    [
      {:sc_stone,
       [
         val1: instance.val1,
         val2: instance.val2,
         caster_id: instance.source_id,
         source_type: instance.source_type,
         duration: instance.val3,
         no_avoid: true
       ]}
    ]
  end
end
