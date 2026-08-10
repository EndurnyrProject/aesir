defmodule Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames do
  @moduledoc """
  Resolves item creator identities and names.
  """

  import Ecto.Query, only: [from: 2]

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.SessionManager
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft

  @spec names_for([InventoryItem.t()]) :: %{non_neg_integer() => String.t()}
  def names_for(items) do
    ids =
      items
      |> Enum.flat_map(fn item ->
        case ItemCraft.from_map(item.craft) do
          {:ok, %ItemCraft{creator_char_id: id}} -> [id]
          :error -> []
        end
      end)
      |> Enum.uniq()

    case ids do
      [] ->
        %{}

      _ ->
        from(character in Character,
          where: character.id in ^ids,
          select: {character.id, character.name}
        )
        |> Repo.all()
        |> Map.new()
    end
  end

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
