defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.RemoveStatus do
  @moduledoc """
  Remove status action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  alias Aesir.ZoneServer.Mmo.StatusStorage
  require Logger

  @impl true
  def execute(target_id, params, state, _context) do
    # Handle both singular 'status' (new format) and plural 'targets' (old format)
    status_to_remove = params[:status]
    targets = params[:targets] || []

    cond do
      # If status field is present (new format), remove that status
      status_to_remove != nil ->
        Logger.debug("Removing status #{status_to_remove} from target #{target_id}")
        # For backward compatibility, assume target_id is a player ID
        StatusStorage.remove_status(:player, target_id, status_to_remove)
        {:ok, state}

      # If targets field is present (old format), remove those statuses
      targets != [] ->
        Enum.each(targets, fn status_id ->
          Logger.debug("Removing status #{status_id} from target #{target_id}")
          # For backward compatibility, assume target_id is a player ID
          StatusStorage.remove_status(:player, target_id, status_id)
        end)

        {:ok, state}

      # No status specified
      true ->
        Logger.warning("RemoveStatus action called without status or targets specified")
        {:ok, state}
    end
  end
end
