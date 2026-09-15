defmodule Aesir.ZoneServer.Content.Npc.Cities.Lutie.Poze do
  @moduledoc """
  Welcomes visitors to Lutie and guides Snowysnow's story toward Uncle Hairy.

  ## Behavior

  - At story stages 3 or 4, explains Snowysnow's revival and sets stage 4.
  - Otherwise introduces Lutie's festive attractions and facilities.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "xmas", x: 117, y: 304, dir: 4, sprite: 713, name: "Poze", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :xmas_npc, 0) in [3, 4] do
      discuss_snowysnow(ctx)
    else
      welcome_visitor(ctx)
    end
  end

  defp discuss_snowysnow(ctx) do
    ctx
    |> mes("[Poze]")
    |> mes("You've gone to")
    |> mes("^3355FFSnowysnow^000000 and he")
    |> mes("mentioned me?")
    |> next()
    |> mes("[Poze]")
    |> mes("Oh I see...")
    |> mes(
      "He's a snowman that doesn't have any legs. No wonder he hasn't come to visit me. What a shame, what a shame. I guess I better go visit him instead."
    )
    |> next()
    |> mes("[Poze]")
    |> mes(
      "Oh, there is someone who knows how Snowysnow came to be able to speak. That person would be ^3355FFUncle Hairy Cantata^000000..."
    )
    |> next()
    |> mes("[Poze]")
    |> mes(
      "One day when apprentice of the great alchemist visited Lutie, I came to listen in on a conversation between him and Uncle Hairy."
    )
    |> next()
    |> mes("[Poze]")
    |> mes(
      "Long ago, a great alchemist came by Snowysnow's hometown and happened to meet Snowysnow dying, melting down into water. However, Snowysnow was miraculously revived by that Alchemist."
    )
    |> next()
    |> mes("[Poze]")
    |> mes(
      "But that's pretty much all I know. For the actual details, you should ask ^3355FFUncle Hairy Cantata^000000."
    )
    |> set_char_var(:xmas_npc, 4)
    |> close()
  end

  defp welcome_visitor(ctx) do
    ctx
    |> mes("[Poze]")
    |> mes("Welcome to Lutie,")
    |> mes("the town which blesses")
    |> mes("all of its visitors with")
    |> mes("the spirit of Christmas!")
    |> mes("Merry Christmas !")
    |> next()
    |> mes("[Poze]")
    |> mes(
      "Here in this magical land of fun and fancy, you can enjoy the spirit of Christmas all year round~! Isn't that wonderful?"
    )
    |> next()
    |> mes("[Poze]")
    |> mes(
      "Lutie isn't merely just a simple attraction. We have convenient facilities like the other towns, but in a festive environment."
    )
    |> next()
    |> mes("[Poze]")
    |> mes(
      "So if you decide to stay here for a while, you should have all the comforts that you need. Merry Christmas~"
    )
    |> close()
  end
end
