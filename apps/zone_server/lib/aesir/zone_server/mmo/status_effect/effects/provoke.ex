defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Provoke do
  @moduledoc """
  Provoke (SC_PROVOKE).

  Raises the target's attack percentage (val2) while lowering soft DEF
  (val3). Only non-player targets also lose hard DEF. It grants no HIT.
  Wakes targets out of Freeze, Stone, Sleep and Trick Dead.

  Renewal and pre-renewal share these values and target-type rules.
  Undead and status-immune targets cannot be taunted at all in either mode.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_provoke,
    no_dispel: false,
    no_clear_buff: false,
    no_save_infinite: true,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    immunity: [:boss, :undead],
    properties: [:debuff],
    calc_flags: [:batk, :watk, :def, :def2],
    end_on_start: [:sc_freeze, :sc_stone, :sc_sleep, :sc_trickdead],
    icon: :provoke

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def modifiers(instance, context) do
    %{
      atk_rate: instance.val2,
      def_rate: if(Map.get(context, :unit_type) == :player, do: 0, else: -instance.val3),
      def2_rate: -instance.val3
    }
  end

  @impl true
  def on_apply(_target, instance, context) do
    initialized =
      cond do
        Map.get(context, :loaded, false) ->
          instance

        instance.val1 == 10 and instance.source_type != :player and
          not is_nil(instance.source_id) and
            UnitRegistry.unit_exists?(instance.source_type, instance.source_id) ->
          %{instance | val2: 0, val3: 100}

        true ->
          %{instance | val2: 2 + 3 * instance.val1, val3: 5 + 5 * instance.val1}
      end

    {:ok, put_state(initialized, :provoked_by, instance.source_id)}
  end
end
