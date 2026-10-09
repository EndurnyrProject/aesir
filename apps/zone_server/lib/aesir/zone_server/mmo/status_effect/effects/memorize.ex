defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Memorize do
  @moduledoc """
  Foresight (SC_MEMORIZE) grants five eligible timing computations. Classic
  consumes a charge during early timing, even for a failed cast attempt or a
  skill that ignores status cast reductions, unless DEX has already made the
  cast instant. Renewal consumes it during late timing, after validation and
  only when status cast reductions apply. The fifth computation receives the
  reduction before the status ends. Effective learned, equipment-granted, and
  guild skills count; pure preflights and restricted proc casts do not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_memorize,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    no_save: true,
    permanent: true,
    properties: [:buff],
    icon: :memorize

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.StatusStorage

  @charges 5

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok,
     %{instance | val2: @charges}
     |> put_state(:cast_time_reduction, 50)
     |> put_state(:charges, @charges)}
  end

  @doc "Spends one timing charge and ends Foresight after the fifth."
  @spec consume_charge(atom(), integer()) :: :ok
  def consume_charge(type, id) do
    case StatusStorage.get_status(type, id, :sc_memorize) do
      %{state: %{charges: charges}} when charges > 1 ->
        StatusStorage.update_status(type, id, :sc_memorize, fn entry ->
          %{entry | val2: entry.val2 - 1} |> put_state(:charges, entry.state.charges - 1)
        end)

      %{state: %{charges: 1}} ->
        remove_status({type, id}, :sc_memorize)

      _missing ->
        :ok
    end
  end
end
