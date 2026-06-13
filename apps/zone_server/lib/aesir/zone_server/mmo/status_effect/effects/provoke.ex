defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Provoke do
  @moduledoc """
  Provoke (SC_PROVOKE).

  Raises the target's ATK (val2) while lowering its DEF (val3), drawing its
  attention to the caster. Wakes targets out of Freeze, Stone, Sleep and
  Trick Dead.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_provoke,
    properties: [:debuff],
    calc_flags: [:atk, :def, :def2, :hit],
    end_on_start: [:sc_freeze, :sc_stone, :sc_sleep, :sc_trickdead],
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(instance, _context) do
    %{
      atk_rate: instance.val2,
      def_rate: -instance.val3,
      def2_rate: -instance.val3,
      hit: instance.val3
    }
  end

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :provoked_by, instance.source_id)}
  end
end
