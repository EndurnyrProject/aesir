defmodule Aesir.ZoneServer.Script.Dsl.ItemCounts do
  @moduledoc """
  The inventory count and delete buildins for the script DSL: `countitem`,
  `countitem2`, `countitem3`, `delitem`, `delitem2` and `delitem3`.

  The plain forms work by item id; the `2` forms match the identify flag,
  refine, attribute and cards exactly, and the `3` forms the random options
  too (`Unit.Inventory.ItemSearch`). A count adds every non-rental row; a
  delete takes the rows the reference's search takes, ending the script when
  the player lacks enough (after deleting what it already took). The optional
  last argument targets the online player of an account id; an offline target
  reads 0 or ends the script. Imported into scripts via the
  `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [apply_op: 2, no_player!: 1]

  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Inventory.ItemSearch
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "How many of `item_id` the player holds, rentals aside (rAthena `countitem`)."
  @spec count_item(Ctx.t(), integer(), integer() | nil) :: non_neg_integer()
  def count_item(ctx, item_id, account_id \\ nil)
  def count_item(%Ctx{game_state: nil}, _item_id, nil), do: no_player!("count_item/2")
  def count_item(ctx, item_id, account_id), do: count(ctx, item_id, account_id)

  @doc "How many of `item_id` with these exact attributes the player holds (rAthena `countitem2`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec countitem2(
          Ctx.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer() | nil
        ) :: non_neg_integer()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def countitem2(ctx, item, iden, ref, attr, c1, c2, c3, c4, account_id \\ nil),
    do: count(ctx, criteria(item, {iden, ref, attr, c1, c2, c3, c4}, nil), account_id)

  @doc "`countitem2` that also matches the random options (rAthena `countitem3`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec countitem3(
          Ctx.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          ItemOptions.t(),
          integer() | nil
        ) :: non_neg_integer()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def countitem3(ctx, item, iden, ref, attr, c1, c2, c3, c4, options, account_id \\ nil),
    do: count(ctx, criteria(item, {iden, ref, attr, c1, c2, c3, c4}, options), account_id)

  @doc """
  Deletes `qty` of `item_id` from the player (rAthena `delitem`), worn,
  refined or carded rows last; ends the script when the player lacks enough.
  """
  @spec delitem(Ctx.t(), integer(), integer(), integer() | nil) :: Ctx.t()
  def delitem(ctx, item_id, qty, account_id \\ nil),
    do: delete(ctx, item_id, item_id, qty, account_id)

  @doc "Deletes `qty` of `item_id` with these exact attributes (rAthena `delitem2`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec delitem2(
          Ctx.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer() | nil
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def delitem2(ctx, item, qty, iden, ref, attr, c1, c2, c3, c4, account_id \\ nil) do
    criteria = criteria(item, {iden, ref, attr, c1, c2, c3, c4}, nil)
    delete(ctx, item, criteria, qty, account_id)
  end

  @doc "`delitem2` that also matches the random options (rAthena `delitem3`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec delitem3(
          Ctx.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          ItemOptions.t(),
          integer() | nil
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def delitem3(ctx, item, qty, iden, ref, attr, c1, c2, c3, c4, options, account_id \\ nil) do
    criteria = criteria(item, {iden, ref, attr, c1, c2, c3, c4}, options)
    delete(ctx, item, criteria, qty, account_id)
  end

  defp criteria(item, {iden, ref, attr, c1, c2, c3, c4}, options) do
    %{
      nameid: item,
      identify: iden,
      refine: ref,
      attribute: attr,
      enchant_grade: 0,
      cards: [c1, c2, c3, c4],
      options: options
    }
  end

  defp count(%Ctx{game_state: nil}, _target, nil), do: no_player!("countitem")

  defp count(ctx, target, account_id) do
    with true <- match?({:ok, _}, Items.by_id(item_id(target))),
         {:ok, game_state} <- target_state(ctx, account_id) do
      ItemSearch.count(game_state.inventory, target)
    else
      _ -> 0
    end
  end

  defp delete(%Ctx{status: {:error, _}} = ctx, _item, _target, _qty, _account_id), do: ctx

  defp delete(ctx, item, target, qty, account_id) do
    with {:ok, session} <- target_session(ctx, account_id),
         {:ok, _definition} <- Items.by_id(item) do
      cond do
        qty <= 0 -> ctx
        session == :self -> apply_op(ctx, {:delitem, target, qty})
        true -> remote(ctx, session, {:delitem, target, qty})
      end
    else
      :no_player -> Ctx.halt(ctx, :no_player)
      :error -> Ctx.halt(ctx, :unknown_item)
    end
  end

  defp remote(ctx, pid, op) do
    case PlayerSession.script_apply(pid, op) do
      {:error, reason} -> Ctx.halt(ctx, reason)
      _ok -> ctx
    end
  end

  defp item_id(%{nameid: nameid}), do: nameid
  defp item_id(item_id), do: item_id

  defp target_state(%Ctx{game_state: game_state}, nil), do: {:ok, game_state}
  defp target_state(%Ctx{account_id: own, game_state: game_state}, own), do: {:ok, game_state}

  defp target_state(_ctx, account_id) do
    with {:ok, char_id} <- UnitRegistry.get_char_id_by_account(account_id),
         {:ok, {_module, game_state, _pid}} <- UnitRegistry.get_unit(:player, char_id) do
      {:ok, game_state}
    end
  end

  defp target_session(%Ctx{session_pid: nil}, nil), do: :no_player
  defp target_session(_ctx, nil), do: {:ok, :self}
  defp target_session(%Ctx{account_id: own}, own), do: {:ok, :self}

  defp target_session(_ctx, account_id) do
    with {:ok, char_id} <- UnitRegistry.get_char_id_by_account(account_id),
         {:ok, {_module, _game_state, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id) do
      {:ok, pid}
    else
      _ -> :no_player
    end
  end
end
