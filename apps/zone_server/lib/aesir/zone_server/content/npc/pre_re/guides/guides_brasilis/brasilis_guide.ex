defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesBrasilis.BrasilisGuide do
  @moduledoc """
  Brasilis guide who directs visitors to local attractions.

  ## Behavior

  - Describes and marks a selected destination on the mini-map.
  - Removes all five destination marks on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "brasilis",
        x: 219,
        y: 97,
        dir: 3,
        sprite: 478,
        name: "Brasilis Guide",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"[ Hotel ]", ["The Brasilis Hotel is located just above, ^FF3355+^000000."],
     {274, 151, 2, 0xFF3355}},
    {"[ Jungle Cable ]",
     [
       "Do you want to go through the rough jungle? You can take a ",
       "Jungle Cable here ^CE6300+^000000."
     ], {308, 335, 3, 0xCE6300}},
    {"[ Art Museum ]",
     ["The pride of Brasilis, the world scale Art Museum is at ^A5BAAD+^000000."],
     {137, 167, 4, 0x00FF00}},
    {"[ Market ]", ["You can buy items for hunting at the Market here ^55FF33+^000000."],
     {254, 248, 5, 0x55FF33}},
    {"[ Verass Monument ]",
     ["The iconic monument of Brasilis, the Verass Monument stands at ^3355FF+^000000."],
     {195, 235, 6, 0x3355FF}}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Brasilis Guide]")
      |> mes("Welcome to ^8B4513Brasilis^000000, a country as passionate as the sun.")
      |> mes("If you have any questions, please ask me.")
      |> next()
      |> select(["Ask about locations", "Remove Marks from Mini-Map", "Cancel"])

    case choice do
      1 ->
        locations(ctx)

      2 ->
        remove_marks(ctx)

      3 ->
        ctx
        |> mes("[Brasilis Guide]")
        |> mes("Wandering on your own is always the best way to explore. Anyway, take care.")
        |> close()

      _ ->
        ctx
    end
  end

  defp locations(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Brasilis Guide]")
      |> mes("Where can I guide you?")
      |> next()
      |> select(Enum.map(@locations, &elem(&1, 0)))

    case choice do
      choice when choice in 1..5 ->
        {_label, lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)

        ctx = Enum.reduce(lines, mes(ctx, "[Brasilis Guide]"), &mes(&2, &1))

        ctx
        |> mes("Is there anything else I can do for you?")
        |> viewpoint(1, x, y, id, color)
        |> close()

      _ ->
        ctx
    end
  end

  defp remove_marks(ctx) do
    ctx
    |> mes("[Brasilis Guide]")
    |> mes("I'll remove all marks from your mini-map.")
    |> mes("Is there anything else I can do for you?")
    |> viewpoint(0, 274, 151, 2, 0x00FF00)
    |> viewpoint(0, 308, 335, 3, 0x00FF00)
    |> viewpoint(0, 137, 167, 4, 0x00FF00)
    |> viewpoint(0, 254, 248, 5, 0x00FF00)
    |> viewpoint(0, 195, 235, 6, 0x00FF00)
    |> close()
  end
end
