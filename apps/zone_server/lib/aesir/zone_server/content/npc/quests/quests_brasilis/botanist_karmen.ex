defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.BotanistKarmen do
  @moduledoc """
  Botanist Karmen begins and rewards the Water Lily quest.

  ## Behavior

  - Introduces the Water Lily quest and directs adventurers to Marta.
  - Completes the quest and awards experience based on VIP status and game mode.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 203,
        y: 286,
        dir: 3,
        sprite: 893,
        name: "Botanist Karmen",
        scope: :shared,
        unique_name: "Botanist Karmen#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_regia, 0) do
      0 -> introduce(ctx)
      1 -> directions(ctx)
      9 -> reward(ctx)
      _ -> discuss_botany(ctx)
    end
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Karmen]")
      |> mes("Brasilis' climate is special.")
      |> mes(
        "This climate offers special cases in botany classes different from any other regions of the world."
      )
      |> next()
      |> mes("[Karmen]")
      |> mes("The plants here have robust frames and are clear and colorful.")
      |> mes("Here the plants are really huge and we can feel their presence.")
      |> next()
      |> mes("[Karmen]")
      |> mes("One of them, a Water Lily, is a really gorgeous and unique plant.")
      |> mes("This flower is quite sensitive so it doesn't bloom everywhere.")
      |> next()
      |> select(["Interesting.", "End conversation."])

    if choice == 2 do
      ctx |> mes("[Karmen]") |> mes("I guess you aren't interested in botany.") |> close()
    else
      describe_lily(ctx)
    end
  end

  defp describe_lily(ctx) do
    ctx
    |> mes("[Karmen]")
    |> mes(
      "It doesn't appear easily and it is a mysterious flower even to the natives, so the Brasilis people believe that a person will get great luck if someone finds it."
    )
    |> next()
    |> mes("[Karmen]")
    |> mes(
      "As a botanist, I have been hanging around here to find the lucky flower but as I expected, it hasn't shown itself yet."
    )
    |> next()
    |> mes("[Karmen]")
    |> mes(
      "I believe that with enough perseverence, this flower will show me it's beautiful brilliance."
    )
    |> next()
    |> mes("[Karmen]")
    |> mes("Ah, if you are interested more in the Water Lily story, find someone named Marta.")
    |> mes("She is wise and knows lots of stories here in Brasilis.")
    |> set_char_var(:brazil_regia, 1)
    |> setquest(2201)
    |> close()
  end

  defp directions(ctx) do
    ctx
    |> mes("[Karmen]")
    |> mes("Ah, if you are interested more in the Water Lily story, find someone named Marta.")
    |> mes("She is wise and knows lots of stories here in Brasilis.")
    |> close()
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("- You show a lotus flower to Karmen and talk about the story so far. -")
      |> next()
      |> mes("[Karmen]")
      |> mes("Wow!! You had a really good experience.")
      |> mes("So~~~ the water lily lives in the depths of brasilis, right?")
      |> mes("I wil try to find it again by myself, I won't give up!!")
      |> next()
      |> mes("[Karmen]")
      |> mes("I am so grateful that I met you.")
      |> mes("The water lily must truly be a lucky flower. hahaha")
      |> set_char_var(:brazil_regia, 10)
      |> completequest(2207)

    ctx =
      if Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) and
           Rathena.truthy?(vip_status(ctx, 1)) do
        getexp(ctx, 75_000, if(Rathena.truthy?(checkre(ctx, 0)), do: 15_000, else: 0))
      else
        getexp(ctx, 50_000, if(Rathena.truthy?(checkre(ctx, 0)), do: 10_000, else: 0))
      end

    close(ctx)
  end

  defp discuss_botany(ctx) do
    ctx
    |> mes("[Karmen]")
    |> mes(
      "This climate offers special cases in botany classes different from any other regions of the world."
    )
    |> next()
    |> mes("[Karmen]")
    |> mes("The plants here have robust frames and are clear and colorful.")
    |> mes("Here the plants are really huge and we can feel their presence.")
    |> next()
    |> mes("[Karmen]")
    |> mes("It's a botanist's dream.")
    |> close()
  end
end
