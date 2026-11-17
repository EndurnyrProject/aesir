defmodule Aesir.ZoneServer.Unit.Pet.Clock do
  @moduledoc "Generation-stamped timers for the owner's pet."

  @doc "Arms a pet timer in the current process."
  @spec arm(non_neg_integer(), atom(), non_neg_integer()) :: reference()
  def arm(delay_ms, event, generation) do
    :erlang.start_timer(delay_ms, self(), {:pet, {event, generation}})
  end

  @doc "Cancels a pet timer when present."
  @spec cancel(reference() | nil) :: :ok
  def cancel(nil), do: :ok

  def cancel(ref) when is_reference(ref) do
    Process.cancel_timer(ref)
    :ok
  end
end
