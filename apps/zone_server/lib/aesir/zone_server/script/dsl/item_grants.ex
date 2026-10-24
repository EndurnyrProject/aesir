defmodule Aesir.ZoneServer.Script.Dsl.ItemGrants do
  @moduledoc """
  The attribute-carrying item grant buildins for the script DSL: `getitem2`,
  `getitem3`, `getitembound2`, `getitembound3`, `rentitem2` and `rentitem3`,
  and the floor item buildins `makeitem2` and `makeitem3`.

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
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.FloorCell
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
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
  2 guild, 3 party, 4 character; any other value fails the command and the
  script goes on.
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
  (rAthena `rentitem` with its target); an offline target fails the command and
  the script goes on.
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

  @doc """
  Puts `amount` of `item` with explicit attributes on the floor of `map`
  (`"this"` is the attached player's map) next to `{x, y}` (rAthena
  `makeitem2`), owned by nobody. The trailing drop-effect flag is accepted;
  the floor item message has no effect field.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec makeitem2(
          Ctx.t(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def makeitem2(ctx, item, amount, map, x, y, iden, ref, attr, c1, c2, c3, c4, _effect \\ 0),
    do: make(ctx, item, amount, map, {x, y}, {iden, ref, attr, c1, c2, c3, c4}, [])

  @doc "`makeitem2` with random options (rAthena `makeitem3`)."
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec makeitem3(
          Ctx.t(),
          integer(),
          integer(),
          String.t(),
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
          integer()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def makeitem3(
        ctx,
        item,
        amount,
        map,
        x,
        y,
        iden,
        ref,
        attr,
        c1,
        c2,
        c3,
        c4,
        options,
        _effect \\ 0
      ),
      do: make(ctx, item, amount, map, {x, y}, {iden, ref, attr, c1, c2, c3, c4}, options)

  defp make(%Ctx{status: {:error, _}} = ctx, _item, _amount, _map, _cell, _fixed, _options),
    do: ctx

  defp make(ctx, item, amount, map, {x, y}, fixed, options) do
    with {:ok, definition} <- Items.by_id(item),
         {:ok, map_name} <- floor_map(ctx, map) do
      attrs = attributes(definition, fixed)
      {cx, cy} = FloorCell.around(map_name, x, y)

      extras = %{
        refine: attrs.refine,
        attribute: attrs.attribute,
        cards: [attrs.card0, attrs.card1, attrs.card2, attrs.card3],
        random_options: options
      }

      if amount > 0 do
        entry = GroundItem.entry(item, amount, cx, cy, attrs.identify != 0, extras)
        Coordinator.drop_items(map_name, [entry], cx, cy)
      end

      ctx
    else
      :error -> Ctx.fail(ctx, :makeitem2, :unknown_item)
      :no_player -> Ctx.halt(ctx, :no_player)
      :unknown_map -> ctx
    end
  end

  defp floor_map(%Ctx{game_state: nil}, "this"), do: :no_player
  defp floor_map(%Ctx{game_state: game_state}, "this"), do: {:ok, game_state.map_name}

  defp floor_map(_ctx, map) do
    case MapCache.get(map) do
      {:ok, _map} -> {:ok, String.replace_suffix(map, ".gat", "")}
      _ -> :unknown_map
    end
  end

  defp bound_grant(ctx, item, qty, fixed, bound, extra, account_id) when bound in 0..4,
    do: grant(ctx, item, qty, fixed, Map.put(extra, :bound, bound), account_id, :getitem)

  defp bound_grant(%Ctx{status: {:error, _}} = ctx, _item, _qty, _fixed, _bound, _extra, _acc),
    do: ctx

  defp bound_grant(ctx, _item, _qty, _fixed, _bound, _extra, _account_id),
    do: Ctx.fail(ctx, :getitembound, :bad_bound)

  defp grant(%Ctx{status: {:error, _}} = ctx, _item, _qty, _fixed, _extra, _account_id, _kind),
    do: ctx

  # The target is resolved before the item, as the reference does.
  defp grant(ctx, item, qty, fixed, extra, account_id, kind) do
    with {:ok, target} <- target(ctx, account_id),
         {:ok, definition} <- Items.by_id(item) do
      deliver(
        ctx,
        target,
        {:give_item2, item, qty, Map.merge(attributes(definition, fixed), extra)}
      )
    else
      :skip -> ctx
      :no_player -> Ctx.halt(ctx, :no_player)
      :error -> Ctx.fail(ctx, kind, :unknown_item)
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

  # No explicit account: the attached player, whose absence ends the script.
  defp target(%Ctx{session_pid: nil}, nil), do: :no_player
  defp target(_ctx, nil), do: {:ok, :self}
  defp target(%Ctx{account_id: own}, own), do: {:ok, :self}

  defp target(_ctx, account_id) do
    with {:ok, char_id} <- UnitRegistry.get_char_id_by_account(account_id),
         {:ok, {_module, _game_state, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id) do
      {:ok, pid}
    else
      _offline -> :skip
    end
  end

  defp deliver(ctx, :self, op), do: apply_op(ctx, op)

  defp deliver(ctx, pid, op) do
    case PlayerSession.script_apply(pid, op) do
      {:error, reason} -> Ctx.fail(ctx, elem(op, 0), reason)
      _ok -> ctx
    end
  end
end
