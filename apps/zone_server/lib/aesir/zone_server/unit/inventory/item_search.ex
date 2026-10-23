defmodule Aesir.ZoneServer.Unit.Inventory.ItemSearch do
  @moduledoc """
  How scripts count and delete inventory items by id or by exact attributes.

  An item's cards are compared as the reference's card values, so a signed
  or forged item compares by its `ItemCraft.card_words/1`.

  Counting adds every row of the item that is not a rental (or, for a rental
  count, every rental row); an exact count also requires the identify flag,
  refine, attribute, enchant grade and cards, and with options the options.

  Deleting runs the reference's search twice, first only counting and then
  deleting. Each run takes, in index order, the unequipped rows that match
  best (by id only: unrefined and card-less; exact: unequipped with the
  requested refine), and when it skipped a row for being equipped or not
  matching that way, takes any other matching row in a second pass. The
  counting run does not consume what its first pass took, so a row can count
  twice and the deleting run can then fall short after deleting part of the
  request; the search behaves exactly that way.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft

  @typedoc "Exact attributes to match; `options: nil` skips the option compare."
  @type criteria :: %{
          nameid: integer(),
          identify: integer(),
          refine: integer(),
          attribute: integer(),
          enchant_grade: integer(),
          cards: [integer()],
          options: ItemOptions.t() | nil
        }

  @typedoc "What to delete: an item id alone, or exact attributes."
  @type target :: integer() | criteria()

  @typedoc "Rows to delete from, in order: `{inventory index, amount}`."
  @type plan :: [{non_neg_integer(), pos_integer()}]

  @doc "Counts the rows of `target` that are not rentals."
  @spec count(%{non_neg_integer() => InventoryItem.t()}, target()) :: non_neg_integer()
  def count(inventory, target) do
    inventory
    |> rows()
    |> Enum.filter(fn {_index, item} ->
      item.amount >= 1 and is_nil(item.expire_time) and count_match?(item, target)
    end)
    |> Enum.sum_by(fn {_index, item} -> item.amount end)
  end

  defp count_match?(item, nameid) when is_integer(nameid), do: item.nameid == nameid
  defp count_match?(item, criteria), do: item.nameid == criteria.nameid and exact?(item, criteria)

  @doc """
  Plans deleting `amount` of `target`: `{:ok, plan}` when the deleting run
  takes it all, `{:error, plan}` with the rows the deleting run took when it
  fell short (an empty plan when the counting run already fell short).
  """
  @spec delete_plan(%{non_neg_integer() => InventoryItem.t()}, target(), pos_integer()) ::
          {:ok, plan()} | {:error, plan()}
  def delete_plan(inventory, target, amount) do
    rows = rows(inventory)
    held = Map.new(rows, fn {index, item} -> {index, item.amount} end)

    case search(held, rows, target, amount, false) do
      {_held, 0, _counted} ->
        case search(held, rows, target, amount, true) do
          {_held, 0, plan} -> {:ok, Enum.reverse(plan)}
          {_held, _short, plan} -> {:error, Enum.reverse(plan)}
        end

      _short ->
        {:error, []}
    end
  end

  # One run of the search. `held` is each row's amount; the deleting run
  # consumes it, the counting run leaves it untouched.
  defp search(held, rows, target, amount, delete?) do
    {held, amount, plan, important} =
      Enum.reduce(rows, {held, amount, [], 0}, &first_pass_row(&1, &2, target, delete?))

    if amount == 0 or important == 0,
      do: {held, amount, plan},
      else: Enum.reduce(rows, {held, amount, plan}, &second_pass_row(&1, &2, target, delete?))
  end

  defp first_pass_row(_row, {_held, 0, _plan, _important} = acc, _target, _delete?), do: acc

  defp first_pass_row({index, item}, {held, amount, plan, important} = acc, target, delete?) do
    case first_pass(item, Map.fetch!(held, index), target) do
      :skip -> acc
      :important -> {held, amount, plan, important + 1}
      :take -> held |> take(index, amount, plan, delete?) |> Tuple.insert_at(3, important)
    end
  end

  defp second_pass_row(_row, {_held, 0, _plan} = acc, _target, _delete?), do: acc

  defp second_pass_row({index, item}, {held, amount, plan} = acc, target, delete?) do
    if Map.fetch!(held, index) > 0 and second_pass?(item, target),
      do: take(held, index, amount, plan, delete?),
      else: acc
  end

  defp take(held, index, amount, plan, delete?) do
    taken = min(amount, Map.fetch!(held, index))
    held = if delete?, do: Map.update!(held, index, &(&1 - taken)), else: held
    {held, amount - taken, [{index, taken} | plan]}
  end

  defp first_pass(_item, 0, _target), do: :skip

  defp first_pass(item, _held, nameid) when is_integer(nameid) do
    cond do
      item.nameid != nameid -> :skip
      item.equip != 0 or item.refine != 0 -> :important
      card_words(item) != [0, 0, 0, 0] -> :important
      true -> :take
    end
  end

  defp first_pass(item, _held, criteria) do
    cond do
      item.nameid != criteria.nameid -> :skip
      item.equip != 0 or item.refine != criteria.refine -> :important
      exact?(item, criteria) -> :take
      true -> :skip
    end
  end

  defp second_pass?(item, nameid) when is_integer(nameid), do: item.nameid == nameid

  defp second_pass?(item, criteria),
    do: item.nameid == criteria.nameid and exact?(item, criteria)

  defp exact?(item, criteria) do
    item.identify == criteria.identify and item.refine == criteria.refine and
      item.attribute == criteria.attribute and item.enchant_grade == criteria.enchant_grade and
      card_words(item) == criteria.cards and
      (is_nil(criteria.options) or
         ItemOptions.pad(item.random_options) == ItemOptions.pad(criteria.options))
  end

  @doc "The four card values an inventory row carries, its craft encoded as cards."
  @spec card_words(InventoryItem.t()) :: [integer()]
  def card_words(%InventoryItem{} = item) do
    case ItemCraft.from_map(item.craft) do
      {:ok, craft} -> ItemCraft.card_words(craft)
      :error -> [item.card0, item.card1, item.card2, item.card3]
    end
  end

  defp rows(inventory), do: Enum.sort_by(inventory, fn {index, _item} -> index end)
end
