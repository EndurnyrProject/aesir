defmodule Aesir.ZoneServer.Unit.AttackIntent do
  @moduledoc """
  Dispatches a typed, one-way request for a player or mob to attack a target.
  """

  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Sends one best-effort attack intent to the holder's owning session."
  @spec start(Ref.t(), Ref.t()) :: :ok | {:error, :invalid_ref | :unsupported_holder}
  def start({holder_type, holder_id} = holder, target) do
    with true <- Ref.valid?(holder) and Ref.valid?(target),
         true <- holder_type in [:player, :mob] do
      dispatch(holder_type, holder_id, target)
    else
      false when holder_type in [:player, :mob] -> {:error, :invalid_ref}
      false -> {:error, :unsupported_holder}
    end
  end

  def start(_holder, _target), do: {:error, :invalid_ref}

  defp dispatch(holder_type, holder_id, target) do
    case UnitRegistry.get_unit(holder_type, holder_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> send(pid, {:attack_intent, target})
      _ -> :ok
    end

    :ok
  end
end
