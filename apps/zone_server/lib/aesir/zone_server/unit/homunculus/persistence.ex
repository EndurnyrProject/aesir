defmodule Aesir.ZoneServer.Unit.Homunculus.Persistence do
  @moduledoc """
  Synchronous persistence boundary for the player-owned Homunculus aggregate.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Repo
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps

  alias Ecto.Multi

  @checkpoint_fields [:hp, :sp, :active_remaining_ms, :cooldowns]
  @checkpoint_string_fields %{
    "hp" => :hp,
    "sp" => :sp,
    "active_remaining_ms" => :active_remaining_ms,
    "cooldowns" => :cooldowns
  }

  @type inventory :: Inventory.t()
  @type item_change :: nil | {inventory(), Inventory.change()}
  @type checkpoint_field :: :hp | :sp | :active_remaining_ms | :cooldowns
  @type checkpoint_key :: checkpoint_field() | String.t()
  @type checkpoint_attrs :: %{optional(checkpoint_key()) => non_neg_integer() | map()}
  @type transaction_result ::
          {:ok, inventory(), Homunculus.t() | nil} | {:error, {atom(), term()}}

  @doc "Loads the character's sole Homunculus row, or `nil` when absent."
  @spec load_for_character(pos_integer()) :: Homunculus.t() | nil
  def load_for_character(character_id) do
    Repo.one(from h in Homunculus, where: h.character_id == ^character_id)
  end

  @doc "Creates a Homunculus, atomically persisting an optional inventory change."
  @spec create_with_item(pos_integer(), map(), inventory(), item_change()) :: transaction_result()
  def create_with_item(character_id, attrs, old_inventory, item_change) do
    changeset =
      %Homunculus{}
      |> Homunculus.changeset(
        attrs
        |> drop_character_id()
        |> Map.put(:character_id, character_id)
      )

    Multi.new()
    |> inventory_change(character_id, old_inventory, item_change)
    |> Multi.insert(:homunculus, changeset)
    |> transact()
  end

  @doc "Updates an owned Homunculus, atomically persisting an optional inventory change."
  @spec transition_with_item(
          pos_integer(),
          Homunculus.t(),
          map(),
          inventory(),
          item_change()
        ) :: transaction_result()
  def transition_with_item(
        character_id,
        %Homunculus{character_id: character_id} = homunculus,
        attrs,
        old_inventory,
        item_change
      ) do
    changeset = Homunculus.changeset(homunculus, drop_character_id(attrs))

    Multi.new()
    |> inventory_change(character_id, old_inventory, item_change)
    |> Multi.update(:homunculus, changeset)
    |> transact()
  end

  def transition_with_item(_character_id, %Homunculus{}, _attrs, _inventory, _item_change) do
    {:error, {:ownership, :character_mismatch}}
  end

  @doc "Synchronously persists a durable semantic transition."
  @spec save_semantic(Homunculus.t(), map()) ::
          {:ok, Homunculus.t()} | {:error, Ecto.Changeset.t()}
  def save_semantic(%Homunculus{} = homunculus, attrs) do
    homunculus
    |> Homunculus.changeset(drop_character_id(attrs))
    |> Repo.update()
  end

  @doc """
  Persists only `hp`, `sp`, `active_remaining_ms`, and `cooldowns`.

  Atom and string keys are accepted. Unknown fields or duplicate atom/string
  representations return `{:error, :invalid_checkpoint_fields}` without writing.
  """
  @spec checkpoint(Homunculus.t(), checkpoint_attrs()) ::
          {:ok, Homunculus.t()}
          | {:error, Ecto.Changeset.t() | :invalid_checkpoint_fields}
  def checkpoint(%Homunculus{} = homunculus, attrs) do
    with {:ok, normalized_attrs} <- normalize_checkpoint_attrs(attrs) do
      save_semantic(homunculus, normalized_attrs)
    end
  end

  @doc "Permanently deletes a Homunculus with an optional inventory change."
  @spec delete(Homunculus.t(), inventory() | {inventory(), item_change()}) :: transaction_result()
  def delete(%Homunculus{} = homunculus, old_inventory) when is_map(old_inventory) do
    delete(homunculus, {old_inventory, nil})
  end

  def delete(%Homunculus{} = homunculus, {old_inventory, item_change}) do
    Multi.new()
    |> inventory_change(homunculus.character_id, old_inventory, item_change)
    |> Multi.delete(:homunculus, homunculus)
    |> transact_delete()
  end

  defp inventory_change(multi, _character_id, old_inventory, nil) do
    Multi.put(multi, :inventory, old_inventory)
  end

  defp inventory_change(multi, character_id, old_inventory, {new_inventory, change}) do
    Multi.run(multi, :inventory, fn _repo, _changes ->
      InventoryOps.persist_change(character_id, old_inventory, new_inventory, change)
    end)
  end

  defp drop_character_id(attrs), do: Map.drop(attrs, [:character_id, "character_id"])

  defp normalize_checkpoint_attrs(attrs) do
    Enum.reduce_while(attrs, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      with {:ok, normalized_key} <- normalize_checkpoint_key(key),
           false <- Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        _invalid -> {:halt, {:error, :invalid_checkpoint_fields}}
      end
    end)
  end

  defp normalize_checkpoint_key(key) when key in @checkpoint_fields, do: {:ok, key}

  defp normalize_checkpoint_key(key) when is_binary(key),
    do: Map.fetch(@checkpoint_string_fields, key)

  defp normalize_checkpoint_key(_key), do: :error

  defp transact(multi) do
    case Repo.transact(multi) do
      {:ok, %{inventory: inventory, homunculus: homunculus}} ->
        {:ok, inventory, homunculus}

      {:error, operation, reason, _changes} ->
        {:error, {operation, reason}}
    end
  end

  defp transact_delete(multi) do
    case Repo.transact(multi) do
      {:ok, %{inventory: inventory}} ->
        {:ok, inventory, nil}

      {:error, operation, reason, _changes} ->
        {:error, {operation, reason}}
    end
  end
end
