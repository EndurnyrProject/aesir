defmodule Aesir.ZoneServer.Unit.Homunculus.StateCommit do
  @moduledoc """
  Replaces the Homunculus nested in its owning player session.
  """

  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc """
  Stores `homunculus` in `session` and marks the owner-private view dirty.

  World registry and spatial publication begin with the active-world task.
  """
  @spec commit(SessionState.t(), HomunculusState.t() | nil) :: SessionState.t()
  def commit(
        %SessionState{homunculus_runtime: %Runtime{} = runtime} = session,
        homunculus
      )
      when is_struct(homunculus, HomunculusState) or is_nil(homunculus) do
    %{
      session
      | homunculus: homunculus,
        homunculus_runtime: %{runtime | private_dirty: true}
    }
  end
end
