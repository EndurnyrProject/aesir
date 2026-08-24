defmodule Aesir.ZoneServer.Guild.Storage.Persistence do
  @moduledoc """
  Low-level Ecto access for guild storage and its audit log.

  The domain core stays pure while callers compose these writes inside
  `transaction/1`. Updates and deletes are guarded by the stored amount so a
  stale writer cannot overwrite another member's movement.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.GuildStorageItem
  alias Aesir.Commons.Models.GuildStorageLog
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Repo

  @doc "Loads a guild's storage rows ordered by row `id`."
  @spec load_storage(integer()) :: [GuildStorageItem.t()]
  def load_storage(guild_id) do
    GuildStorageItem
    |> where([item], item.guild_id == ^guild_id)
    |> order_by([item], item.id)
    |> Repo.all()
  end

  @doc "Inserts a new item for the given guild."
  @spec insert_item(integer(), map()) ::
          {:ok, GuildStorageItem.t()} | {:error, Ecto.Changeset.t()}
  def insert_item(guild_id, attrs) do
    %GuildStorageItem{}
    |> GuildStorageItem.changeset(Map.put(attrs, :guild_id, guild_id))
    |> Repo.insert()
  end

  @doc "Updates a row only when it still holds `expected_amount`."
  @spec update_amount(integer(), integer(), pos_integer(), pos_integer()) ::
          :ok | {:error, :stale}
  def update_amount(guild_id, row_id, expected_amount, new_amount) do
    {count, _} =
      GuildStorageItem
      |> where(
        [item],
        item.id == ^row_id and item.guild_id == ^guild_id and item.amount == ^expected_amount
      )
      |> Repo.update_all(set: [amount: new_amount, updated_at: NaiveDateTime.utc_now(:second)])

    if count == 1, do: :ok, else: {:error, :stale}
  end

  @doc "Deletes a row only when it still holds `expected_amount`."
  @spec delete_item(integer(), integer(), pos_integer()) :: :ok | {:error, :stale}
  def delete_item(guild_id, row_id, expected_amount) do
    {count, _} =
      GuildStorageItem
      |> where(
        [item],
        item.id == ^row_id and item.guild_id == ^guild_id and item.amount == ^expected_amount
      )
      |> Repo.delete_all()

    if count == 1, do: :ok, else: {:error, :stale}
  end

  @doc "Appends a signed item movement to the guild storage audit log."
  @spec log(integer(), integer(), InventoryItem.t(), integer()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def log(guild_id, char_id, %InventoryItem{} = item, amount) do
    attrs = %{
      guild_id: guild_id,
      char_id: char_id,
      nameid: item.nameid,
      amount: amount,
      refine: item.refine,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      unique_id: item.unique_id
    }

    with {:ok, _log} <- GuildStorageLog.changeset(%GuildStorageLog{}, attrs) |> Repo.insert() do
      :ok
    end
  end

  @doc "Runs `fun` inside a database transaction."
  @spec transaction((-> {:ok, term()} | {:error, term()})) :: {:ok, term()} | {:error, term()}
  def transaction(fun) when is_function(fun, 0) do
    Repo.transact(fun)
  end

  @doc "Converts a guild-storage row into an in-session inventory item."
  @spec to_session_item(GuildStorageItem.t()) :: InventoryItem.t()
  def to_session_item(%GuildStorageItem{} = row) do
    %InventoryItem{
      id: row.id,
      nameid: row.nameid,
      amount: row.amount,
      equip: 0,
      identify: row.identify,
      refine: row.refine,
      attribute: row.attribute,
      card0: row.card0,
      card1: row.card1,
      card2: row.card2,
      card3: row.card3,
      craft: row.craft,
      random_options: row.random_options,
      expire_time: row.expire_time,
      bound: row.bound,
      unique_id: row.unique_id,
      enchant_grade: row.enchant_grade
    }
  end

  @doc "Converts an in-session inventory item into guild-storage insert attributes."
  @spec to_row_attrs(InventoryItem.t()) :: map()
  def to_row_attrs(%InventoryItem{} = item) do
    %{
      nameid: item.nameid,
      amount: item.amount,
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      craft: item.craft,
      random_options: item.random_options,
      expire_time: item.expire_time,
      bound: item.bound,
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade
    }
  end
end
