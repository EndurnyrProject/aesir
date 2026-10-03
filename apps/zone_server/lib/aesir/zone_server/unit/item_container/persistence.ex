defmodule Aesir.ZoneServer.Unit.ItemContainer.Persistence do
  @moduledoc """
  Shared low-level Ecto access for item-container rows.

  Inventory, cart and storage rows differ only in their schema and owner
  column (`char_id` or `account_id`). The per-container `Persistence` modules
  delegate here and keep their own names so callers and test stubs stay
  container-specific.
  """

  import Ecto.Query

  alias Aesir.Repo

  @type row :: struct()
  @type item_result :: {:ok, row()} | {:error, Ecto.Changeset.t()}

  @doc "Loads every row of `schema` owned by `owner_id`, ordered by row `id`."
  @spec load(module(), atom(), integer()) :: [row()]
  def load(schema, owner_column, owner_id) do
    schema
    |> where([i], field(i, ^owner_column) == ^owner_id)
    |> order_by([i], i.id)
    |> Repo.all()
  end

  @doc "Inserts a new `schema` row for `owner_id`."
  @spec insert(module(), atom(), integer(), map()) :: item_result()
  def insert(schema, owner_column, owner_id, attrs) do
    schema
    |> struct()
    |> schema.changeset(Map.put(attrs, owner_column, owner_id))
    |> Repo.insert()
  end

  @doc "Updates an existing row with `attrs` through its schema changeset."
  @spec update(row(), map()) :: item_result()
  def update(%schema{} = item, attrs) do
    item
    |> schema.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a row."
  @spec delete(row()) :: item_result()
  def delete(item), do: Repo.delete(item)

  @doc """
  Runs `fun` inside a database transaction, rolling back when it returns an
  `{:error, reason}` tuple and committing on `{:ok, result}`.
  """
  @spec transaction((-> {:ok, term()} | {:error, term()})) :: {:ok, term()} | {:error, term()}
  def transaction(fun) when is_function(fun, 0), do: Repo.transact(fun)
end
