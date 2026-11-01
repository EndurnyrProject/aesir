defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemDialogs do
  @moduledoc """
  Closed bridge from teleport consumable scripts to their destination helpers.

  Item scripts stage a request without opening a menu. The owning player
  session spends the item before starting its suspendable interaction.
  """

  alias Aesir.ZoneServer.Content.Npc.Functions.FCashCity
  alias Aesir.ZoneServer.Content.Npc.Functions.FCashDungeon
  alias Aesir.ZoneServer.Content.Npc.Functions.FCashSiegeTele
  alias Aesir.ZoneServer.Content.Npc.Functions.FCashTele
  alias Aesir.ZoneServer.Script.Ctx

  @typedoc "An implemented teleport-menu helper."
  @type helper :: :cash_dungeon | :cash_city | :cash_tele | :cash_siege_tele

  @typedoc "A helper and its validated literal arguments."
  @type request :: {helper(), [integer()]}

  @doc "Resolves a supported source helper and its literal arguments."
  @spec resolve(String.t(), [integer()]) :: {:ok, request()} | :error
  def resolve("F_CashDungeon", [type]) when type in 1..3, do: {:ok, {:cash_dungeon, [type]}}
  def resolve("F_CashCity", [type]) when type in 1..5, do: {:ok, {:cash_city, [type]}}
  def resolve("F_CashTele", [type]) when type in 1..6, do: {:ok, {:cash_tele, [type]}}
  def resolve("F_CashSiegeTele", []), do: {:ok, {:cash_siege_tele, []}}
  def resolve(_name, _args), do: :error

  @doc "Returns the content module for a valid staged request."
  @spec target(request()) :: {:ok, module()} | :error
  def target({:cash_dungeon, [type]}) when type in 1..3, do: {:ok, FCashDungeon}
  def target({:cash_city, [type]}) when type in 1..5, do: {:ok, FCashCity}
  def target({:cash_tele, [type]}) when type in 1..6, do: {:ok, FCashTele}
  def target({:cash_siege_tele, []}), do: {:ok, FCashSiegeTele}
  def target(_request), do: :error

  @doc "Stages an item-only helper request without performing any effects."
  @spec stage(Ctx.t(), helper(), [integer()]) :: Ctx.t()
  def stage(%Ctx{source: {:item, _}} = ctx, helper, args) do
    case target({helper, args}) do
      {:ok, _module} ->
        %{ctx | session_effects: ctx.session_effects ++ [{:item_dialog, helper, args}]}

      :error ->
        Ctx.halt(ctx, :invalid_script)
    end
  end
end
