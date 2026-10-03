defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Fury do
  @moduledoc """
  Reads whether a player holds Fury (`sc_explosionspirits`), the state Asura
  Strike and Raging Palm Strike require and Raging Thrust checks before opening
  the Asura window. Identical in renewal and pre-renewal.
  """

  alias Aesir.ZoneServer.Mmo.StatusStorage

  @fury :sc_explosionspirits

  @doc "Whether the player holds an unexpired (or permanent) Fury."
  @spec active?(integer()) :: boolean()
  def active?(character_id) do
    case StatusStorage.get_status(:player, character_id, @fury) do
      %{expires_at: nil} -> true
      %{expires_at: expires_at} when is_integer(expires_at) -> expires_at > now()
      _status -> false
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
