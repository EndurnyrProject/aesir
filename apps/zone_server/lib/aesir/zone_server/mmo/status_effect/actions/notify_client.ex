defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.NotifyClient do
  @moduledoc """
  Client notification action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  @impl true
  def execute(target_id, params, state, _context) do
    packet = params[:packet]
    data = params[:data] || %{}

    # TODO: Send packet to client through player session
    Logger.debug(
      "Notifying client of #{packet} for target #{target_id} with data: #{inspect(data)}"
    )

    # PlayerSession.send_packet(target_id, packet, data)

    {:ok, state}
  end
end
