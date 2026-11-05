defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.LittleKid do
  @moduledoc """
  Cezu arranges flour and eggs for Elly through the Lighthalzen Windmill.

  ## Behavior

  - Sends an adventurer helping Elly to collect baking ingredients.
  - Exchanges the returned delivery package and resets her progress after Elly’s ingredient
    request ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 217,
        y: 114,
        dir: 6,
        sprite: 96,
        name: "Little Kid",
        scope: :shared,
        unique_name: "Little Kid#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Cezu]")

    case get_char_var(ctx, :KielHyreQuest, 0) do
      stage when stage < 6 -> advertise_fresh_toast(ctx)
      6 -> help_elly(ctx)
      stage when stage > 6 -> ctx |> set_char_var(:KHToastGirlEnd, 0) |> advertise_hot_toast()
      _ -> advertise_hot_toast(ctx)
    end
  end

  defp help_elly(ctx) do
    case get_char_var(ctx, :KHToastGirlEnd, 0) do
      stage when stage < 1 -> offer_delivery(ctx)
      1 -> remind_delivery(ctx)
      2 -> divide_ingredients(ctx)
      _ -> advertise_hot_toast(ctx)
    end
  end

  defp offer_delivery(ctx) do
    {ctx, response} =
      ctx
      |> mes("Fresh, crunchy toast!")
      |> mes("If you want some, come")
      |> mes("and get some tooooast~")
      |> mes("Oh! Hi hi~ Did you want")
      |> mes("to buy some yummy toast?")
      |> next()
      |> select(["I'm here for Elly", "No, thanks"])

    case response do
      1 -> request_ingredients(ctx)
      2 -> ctx |> mes("[Cezu]") |> mes("Okay okay~") |> mes("Please come again!") |> close()
      _ -> ctx
    end
  end

  defp advertise_fresh_toast(ctx) do
    ctx
    |> mes("Fresh, crunchy toast!")
    |> mes("If you want some, come")
    |> mes("and get some tooooast~")
    |> close()
  end

  defp request_ingredients(ctx) do
    ctx
    |> mes("[Cezu]")
    |> mes("Oh, I see. Elly must have")
    |> mes("wasted another batch of")
    |> mes("ingredients again. Well,")
    |> mes("she's a regular customer,")
    |> mes("so I really want to help, but")
    |> mes("I can't really do anything.")
    |> next()
    |> mes("[Cezu]")
    |> mes("You see, I just ran")
    |> mes("out of ingredients too!")
    |> mes("But I can't really leave")
    |> mes("to get some more. What if")
    |> mes("people need to buy toast?")
    |> mes("Listen, can you help me out?")
    |> next()
    |> mes("[Cezu]")
    |> mes("Would you please go get")
    |> mes("some flour and eggs for me")
    |> mes("from the ^3355FFLighthalzen Windmill^000000")
    |> mes("Then, when you come back, I can")
    |> mes("divide the ingredients, and you")
    |> mes("can deliver some to Elly.")
    |> next()
    |> mes("[Cezu]")
    |> mes("I know that I'm basically")
    |> mes("making you do everything")
    |> mes("on your own, but please try")
    |> mes("to understand that my hands")
    |> mes("are tied. D-don't ask me")
    |> mes("why, they just are!")
    |> set_char_var(:KHToastGirlEnd, 1)
    |> close()
  end

  defp remind_delivery(ctx) do
    ctx
    |> mes("Would you please go to")
    |> mes("the Lighthalzen Windmill")
    |> mes("and tell them that Cezu needs")
    |> mes("lots of flour and lots of eggs!")
    |> mes("Then, bring all the stuff over")
    |> mes("to me as soon as you can~")
    |> close()
  end

  defp divide_ingredients(ctx) do
    ctx
    |> mes("Hey, you're back with the")
    |> mes("ingredients! Thank you so")
    |> mes("much, I really needed these!")
    |> mes("Now please give this flour")
    |> mes("and these eggs to Elly, and")
    |> mes("send her my regards. See you~")
    |> delitem(7488, 1)
    |> give_item(7488, 1)
    |> set_char_var(:KHToastGirlEnd, 3)
    |> close()
  end

  defp advertise_hot_toast(ctx) do
    ctx
    |> mes("Hot, fresh and")
    |> mes("cruuuunchy toast!")
    |> mes("Come and get some!")
    |> close()
  end
end
