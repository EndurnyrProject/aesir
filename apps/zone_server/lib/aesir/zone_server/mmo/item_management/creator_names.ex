defmodule Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames do
  @moduledoc """
  Resolves signed-item creators that are currently online.
  """

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.Repo

  @spec resolve_online_target(String.t() | integer()) :: {:ok, integer()} | {:error, term()}
  def resolve_online_target(character_id) when is_integer(character_id) do
    case Repo.get(Character, character_id) do
      nil -> {:error, :not_online}
      character -> resolve_online_character(character)
    end
  end

  def resolve_online_target(name) when is_binary(name) do
    case Repo.get_by(Character, name: name) do
      nil -> {:error, :not_online}
      character -> resolve_online_character(character)
    end
  end

  defp resolve_online_character(%Character{id: character_id, account_id: account_id}) do
    case SessionManager.get_online_user(account_id) do
      {:ok, %{character_id: ^character_id}} -> {:ok, character_id}
      _ -> {:error, :not_online}
    end
  end
end
