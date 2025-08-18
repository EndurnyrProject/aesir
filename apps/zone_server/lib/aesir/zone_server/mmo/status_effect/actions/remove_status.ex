defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.RemoveStatus do
  @moduledoc """
  Remove status action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  alias Aesir.ZoneServer.Mmo.StatusStorage
  require Logger

  @impl true
  def execute(target_id, params, state, _context) do
    targets = params[:targets] || []

    Enum.each(targets, fn status_id ->
      Logger.debug("Removing status #{status_id} from target #{target_id}")
      StatusStorage.remove_status(target_id, status_id)
    end)

    {:ok, state}
  end
end
