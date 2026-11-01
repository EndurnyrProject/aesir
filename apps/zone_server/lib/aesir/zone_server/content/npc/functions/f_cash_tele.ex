defmodule Aesir.ZoneServer.Content.Npc.Functions.FCashTele do
  @moduledoc """
  Offers the regional city and save-point destinations for teleport scrolls.

  ## Behavior

  Each scroll retains its own city list and coordinates. Izlude's landing
  depends on the game mode. Selection warps and ends the calling script.

  ## Credits

  Original function by L0ne_W0lf, with teleport-function updates by Euphy.

  ## Adaptation

  LLM-assisted Elixir port of the shared Cash Shop function.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @doc "Runs the regional menu selected by the first argument."
  @spec call(Ctx.t(), [integer()]) :: {Ctx.t(), integer()} | no_return()
  def call(ctx, args) do
    case destinations(Enum.at(args, 0, 0)) do
      [] ->
        {ctx, 0}

      entries ->
        {ctx, choice} = Dsl.select(ctx, Enum.map(entries, &elem(&1, 0)))
        {_label, {map, x, y}} = Enum.at(entries, choice - 1)
        ctx = Dsl.warp(ctx, map, x, y)
        throw({:script_end, ctx})
    end
  end

  defp destinations(1) do
    izlude = if GameMode.mode() == :renewal, do: {"izlude", 128, 105}, else: {"izlude", 91, 105}

    [
      {"Prontera", {"prontera", 119, 77}},
      {"Geffen", {"geffen", 119, 39}},
      {"Al de Baran", {"aldebaran", 165, 107}},
      {"Izlude", izlude},
      {"Savepoint", {"SavePoint", 0, 0}}
    ]
  end

  defp destinations(2) do
    [
      {"Payon", {"payon", 158, 55}},
      {"Alberta", {"alberta", 115, 57}},
      {"Morocc", {"morocc", 158, 48}},
      {"Comodo", {"comodo", 217, 148}},
      {"Savepoint", {"SavePoint", 0, 0}}
    ]
  end

  defp destinations(3) do
    [
      {"Luoyang", {"louyang", 214, 101}},
      {"Amatsu", {"amatsu", 112, 145}},
      {"Kunlun Field", {"gonryun", 160, 118}},
      {"Ayothaya", {"ayothaya", 216, 175}},
      {"Savepoint", {"SavePoint", 0, 0}}
    ]
  end

  defp destinations(4) do
    [
      {"Lutie Field", {"xmas", 148, 131}},
      {"Umbala", {"umbala", 93, 154}},
      {"Niflheim", {"niflheim", 187, 189}},
      {"Savepoint", {"SavePoint", 0, 0}}
    ]
  end

  defp destinations(5) do
    [
      {"Juno", {"yuno", 157, 124}},
      {"Einbroch", {"einbroch", 230, 192}},
      {"Lighthalzen", {"lighthalzen", 158, 94}},
      {"Hugel", {"hugel", 93, 159}},
      {"Savepoint", {"SavePoint", 0, 0}}
    ]
  end

  defp destinations(6) do
    [
      {"Rachel", {"rachel", 118, 132}},
      {"Veins", {"veins", 214, 125}},
      {"Savepoint", {"SavePoint", 0, 0}}
    ]
  end

  defp destinations(_type), do: []
end
