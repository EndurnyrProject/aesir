defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Hostess do
  @moduledoc """
  Mei Yen Fang serves visitors and shares news about the chief’s stolen belongings.

  ## Behavior

  - Describes the theft and directs players helping the chief to Xue Bong.
  - Changes her greeting as the investigation progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_in",
        x: 152,
        y: 35,
        dir: 4,
        sprite: 702,
        name: "Hostess",
        scope: :shared,
        unique_name: "Hostess#gon"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :b_sword, 0) do
      stage when stage < 1 -> welcome(ctx)
      stage when stage in [1, 2] -> robbery(ctx)
      3 -> point_to_witness(ctx)
      stage when stage < 11 -> worried(ctx)
      stage when stage in [11, 12] -> waiting(ctx)
      _ -> resolved(ctx)
    end
  end

  defp welcome(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mei Yen Fang]")
      |> mes("Oh...you're new here, right?")
      |> mes("Came from out of town?")
      |> mes("It's common to see lots of")
      |> mes("foreigners these days.")
      |> mes("It made people in the village busy.")
      |> next()
      |> mes("[Mei Yen Fang]")
      |> mes("Oh, what am I saying...")
      |> mes("Want some wine?")
      |> next()
      |> select(["Yes, please", "No, it's okay."])

    case choice do
      1 -> out_of_wine(ctx)
      _ -> farewell(ctx)
    end
  end

  defp out_of_wine(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("Oooops~! Oh no...")
    |> mes("A lot of customers came by earlier,")
    |> mes("so now we're out of wine...")
    |> mes("It's getting difficult to keep up with the increasing number of customers...")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("Well, have fun in the village.")
    |> mes("Stop by again sometime.")
    |> close()
  end

  defp robbery(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("Hey, you know what?")
    |> mes("The chief's house was robbed")
    |> mes("last night. I can't believe")
    |> mes("this happened...I guess this is the work of those thieves...")
    |> next()
    |> mes("[Mei Yen Fang]")
    |> mes("How worrisome it all is...")
    |> mes("It could even happen to me!")
    |> mes("I better watch out...")
    |> mes("Oh, what am I saying?")
    |> mes("Enjoy your time in my shop...hehe~")
    |> set_char_var(:b_sword, 2)
    |> close()
  end

  defp point_to_witness(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("Oh, it's you again~")
    |> mes("I heard that you've decided")
    |> mes("to help our chief.")
    |> mes("Please do your best for him!")
    |> mes("Everyone in the village has")
    |> mes("been on edge...")
    |> next()
    |> mes("[Mei Yen Fang]")
    |> mes("Do you see that guy over there")
    |> mes("leaning on the table?")
    |> mes("He seems to know about what")
    |> mes("happened last night, but...")
    |> mes("He's been drinking all night long.")
    |> set_char_var(:b_sword, 4)
    |> close()
  end

  defp worried(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("Hello there~")
    |> mes("Feeling tension in the village,")
    |> mes("huh? It's all because of those")
    |> mes("thieves... ")
    |> next()
    |> mes("[Mei Yen Fang]")
    |> mes("They're also making things hard for my business...")
    |> mes(" ")
    |> mes("*Sigh*")
    |> close()
  end

  defp waiting(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("Feeling tension in the village,")
    |> mes("huh? I Hope the thief will get caught soon.")
    |> mes("...")
    |> close()
  end

  defp resolved(ctx) do
    ctx
    |> mes("[Mei Yen Fang]")
    |> mes("You caught him?!")
    |> mes("Wow, you're very brave.")
    |> mes("I should get ready to run the")
    |> mes("shop again. But I'll need to")
    |> mes("order some wine first.")
    |> next()
    |> mes("[Mei Yen Fang]")
    |> mes("Xue Bong drank all the wine in the")
    |> mes("shop, and I didn't restock any")
    |> mes("since everyone has been scared")
    |> mes("off by the thefts...")
    |> mes("But stop by next time.")
    |> mes("I'll have some wine ready.")
    |> close()
  end
end
