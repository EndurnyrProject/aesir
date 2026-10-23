defmodule Aesir.ZoneServer.Script.Dsl.ItemGrants do
  @moduledoc """
  The attribute-carrying item grant buildins for the script DSL: `getitem2`,
  `getitem3`, `getitembound2`, `getitembound3`, `rentitem2` and `rentitem3`.

  Each grants an item with an identify flag, a refine level, an element
  attribute and four card values, and the `3` variants random options too.
  The item type decides what is kept: weapons, armour and shadow gear keep
  them all with the refine capped at the mode's maximum; a pet egg is
  identified and unrefined; any other item is identified, unrefined and has
  no attribute. A rental grants one unit that expires after the given seconds.

  The optional last argument targets the online player of an account id. A
  `getitem` target that is offline is skipped and the script goes on; a
  `rentitem` target that is offline stops it. Imported into scripts via the
  `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [apply_op: 2]

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @gear [:weapon, :armor, :shadow_gear]

  @typedoc "Identify, refine, attribute and the four cards of a granted item."
  @type fixed ::
          {integer(), integer(), integer(), integer(), integer(), integer(), integer()}

  @doc "Grants `qty` of `item` with explicit attributes (rAthena `getitem2`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec getitem2(
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
  def getitem2(ctx, item, qty, iden, ref, attr, c1, c2, c3, c4, account_id \\ nil),
    do: grant(ctx, item, qty, {iden, ref, attr, c1, c2, c3, c4}, %{}, account_id, :getitem)

  @doc "`getitem2` with random options (rAthena `getitem3`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec getitem3(
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
  def getitem3(ctx, item, qty, iden, ref, attr, c1, c2, c3, c4, options, account_id \\ nil) do
    fixed = {iden, ref, attr, c1, c2, c3, c4}
    grant(ctx, item, qty, fixed, %{random_options: options}, account_id, :getitem)
  end

  @doc """
  `getitem2` with a binding (rAthena `getitembound2`): 0 none, 1 account,
  2 guild, 3 party, 4 character; any other value stops the script.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec getitembound2(
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
          integer(),
          integer() | nil
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def getitembound2(ctx, item, qty, iden, ref, attr, c1, c2, c3, c4, bound, account_id \\ nil),
    do: bound_grant(ctx, item, qty, {iden, ref, attr, c1, c2, c3, c4}, bound, %{}, account_id)

  @doc "`getitembound2` with random options (rAthena `getitembound3`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec getitembound3(
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
          integer(),
          ItemOptions.t(),
          integer() | nil
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def getitembound3(
        ctx,
        item,
        qty,
        iden,
        ref,
        attr,
        c1,
        c2,
        c3,
        c4,
        bound,
        options,
        account_id \\ nil
      ) do
    fixed = {iden, ref, attr, c1, c2, c3, c4}
    bound_grant(ctx, item, qty, fixed, bound, %{random_options: options}, account_id)
  end

  @doc "Rents one `item` with explicit attributes for `seconds` (rAthena `rentitem2`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec rentitem2(
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
  def rentitem2(ctx, item, seconds, iden, ref, attr, c1, c2, c3, c4, account_id \\ nil) do
    fixed = {iden, ref, attr, c1, c2, c3, c4}
    grant(ctx, item, 1, fixed, %{expire_seconds: seconds}, account_id, :rentitem)
  end

  @doc """
  Rents one `item` for `seconds` to the online player of `account_id`
  (rAthena `rentitem` with its target); an offline target stops the script.
  """
  @spec rentitem(Ctx.t(), integer(), integer(), integer()) :: Ctx.t()
  def rentitem(ctx, item, seconds, account_id),
    do:
      grant(
        ctx,
        item,
        1,
        {1, 0, 0, 0, 0, 0, 0},
        %{expire_seconds: seconds},
        account_id,
        :rentitem
      )

  @doc "`rentitem2` with random options (rAthena `rentitem3`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec rentitem3(
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
  def rentitem3(ctx, item, seconds, iden, ref, attr, c1, c2, c3, c4, options, account_id \\ nil) do
    extra = %{expire_seconds: seconds, random_options: options}
    grant(ctx, item, 1, {iden, ref, attr, c1, c2, c3, c4}, extra, account_id, :rentitem)
  end

  defp bound_grant(ctx, item, qty, fixed, bound, extra, account_id) when bound in 0..4,
    do: grant(ctx, item, qty, fixed, Map.put(extra, :bound, bound), account_id, :getitem)

  defp bound_grant(%Ctx{status: {:error, _}} = ctx, _item, _qty, _fixed, _bound, _extra, _acc),
    do: ctx

  defp bound_grant(ctx, _item, _qty, _fixed, _bound, _extra, _account_id),
    do: Ctx.halt(ctx, :bad_bound)

  defp grant(%Ctx{status: {:error, _}} = ctx, _item, _qty, _fixed, _extra, _account_id, _kind),
    do: ctx

  # The target is resolved before the item, as the reference does.
  defp grant(ctx, item, qty, fixed, extra, account_id, kind) do
    with {:ok, target} <- target(ctx, account_id, kind),
         {:ok, definition} <- Items.by_id(item) do
      deliver(
        ctx,
        target,
        {:give_item2, item, qty, Map.merge(attributes(definition, fixed), extra)}
      )
    else
      :skip -> ctx
      :no_player -> Ctx.halt(ctx, :no_player)
      :error -> Ctx.halt(ctx, :unknown_item)
    end
  end

  defp attributes(%ItemDefinition{type: type}, {iden, ref, attr, c1, c2, c3, c4}) do
    {iden, ref, attr} =
      cond do
        type in @gear -> {iden, min(ref, max_refine()), attr}
        type == :pet_egg -> {1, 0, attr}
        true -> {1, 0, 0}
      end

    %{identify: iden, refine: ref, attribute: attr, card0: c1, card1: c2, card2: c3, card3: c4}
  end

  defp max_refine, do: if(GameMode.mode() == :pre_renewal, do: 10, else: 20)

  defp target(_ctx, nil, _kind), do: {:ok, :self}
  defp target(%Ctx{account_id: own}, own, _kind), do: {:ok, :self}

  defp target(_ctx, account_id, kind) do
    with {:ok, char_id} <- UnitRegistry.get_char_id_by_account(account_id),
         {:ok, {_module, _game_state, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id) do
      {:ok, pid}
    else
      _offline when kind == :getitem -> :skip
      _offline -> :no_player
    end
  end

  defp deliver(ctx, :self, op), do: apply_op(ctx, op)

  defp deliver(ctx, pid, op) do
    case PlayerSession.script_apply(pid, op) do
      {:error, reason} -> Ctx.halt(ctx, reason)
      _ok -> ctx
    end
  end
end
