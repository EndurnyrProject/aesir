defmodule Aesir.ZoneServer.Content.Npc.Functions.FCashCity do
  @moduledoc """
  Offers the city destinations for coloured Butterfly Wings.

  ## Behavior

  The five wing variants retain their different city lists in both game
  modes. Izlude's landing coordinates depend on the active mode. Selection
  warps and ends the calling script.

  ## Credits

  Original function by L0ne_W0lf, with teleport-function updates by Euphy.

  ## Adaptation

  LLM-assisted Elixir port of the shared Cash Shop function.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @doc "Runs the city menu selected by the first argument."
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
    izlude = if GameMode.mode() == :renewal, do: {"izlude", 130, 90}, else: {"izlude", 91, 105}

    [
      {"Prontera", {"prontera", 122, 87}},
      {"Izlude", izlude},
      {"Geffen", {"geffen", 128, 48}},
      {"Payon", {"payon", 164, 123}},
      {"Morocc", {"morocc", 160, 100}},
      {"Alberta", {"alberta", 117, 50}},
      {"Al de Baran", {"aldebaran", 140, 110}}
    ]
  end

  defp destinations(2) do
    [
      {"Juno", {"yuno", 160, 170}},
      {"Lighthalzen", {"lighthalzen", 190, 310}},
      {"Einbroch", {"einbroch", 230, 190}},
      {"Einbech", {"einbech", 187, 120}},
      {"Hugel", {"hugel", 92, 165}}
    ]
  end

  defp destinations(3) do
    [
      {"Rachel", {"rachel", 120, 125}},
      {"Veins", {"veins", 215, 105}}
    ]
  end

  defp destinations(4) do
    [
      {"Amatsu", {"amatsu", 110, 140}},
      {"Kunlun", {"gonryun", 160, 115}},
      {"Ayothaya", {"ayothaya", 220, 170}},
      {"Luoyang", {"louyang", 217, 95}}
    ]
  end

  defp destinations(5) do
    destinations(4) ++
      [
        {"Moscovia", {"moscovia", 224, 195}},
        {"Dewata", {"dewata", 200, 107}},
        {"Brasilis", {"brasilis", 196, 181}}
      ]
  end

  defp destinations(_type), do: []
end
