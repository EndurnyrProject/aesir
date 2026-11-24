defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.CandyMaker do
  @moduledoc """
  The Candy Maker sends adventurers in search of guarana and makes candy from it.

  ## Behavior

  - Directs adventurers to Cherto, makes candy from guarana and sells it afterward.

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
      %{map: "brasilis", x: 187, y: 162, dir: 5, sprite: 476, name: "Candy Maker", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if not Rathena.truthy?(checkweight(ctx, [{1201, 1}])) do
      ctx
      |> mes("- You can't start the quest. Please reduce the weight in your inventory. -")
      |> close()
    else
      quest_dialogue(ctx)
    end
  end

  defp quest_dialogue(ctx) do
    case get_char_var(ctx, :brazil_gua, 0) do
      0 ->
        introduce(ctx)

      1 ->
        ctx
        |> mes("[Candy Maker]")
        |> mes("If you want to get the guarana, find Cherto.")
        |> mes("Maybe he will be in the museum.")
        |> close()

      10 ->
        finish_quest(ctx)

      11 ->
        offer_candy(ctx)

      _ ->
        ctx
        |> mes("[Candy Maker]")
        |> mes("Guarana candy. That was the most unique masterpiece in my life for sure!")
        |> close()
    end
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Candy Maker]")
      |> mes("Yo, do you know a berry called ^FF0000Guarana^000000?")
      |> next()
      |> mes("[Candy Maker]")
      |> mes(
        "Guarana is a really special berry raised in a specific area, it relieves physical fatigue, and gives power to the body. It even detoxes waste from the body."
      )
      |> next()
      |> mes("[Candy Maker]")
      |> mes("I used to sell the candy made of it back in the day.")
      |> mes(
        "I got a prize sometimes every year in the <annual best product contest>. Those were the good 'ol days."
      )
      |> next()
      |> mes("[Candy Maker]")
      |> mes(
        "Since then, the output of that fruit has reduced and the price has gone up so now candy ingredients were changed to coconuts or other tropical fruits instead. I miss the guarana candy."
      )
      |> next()
      |> select(["How can I taste this guarana candy?", "End conversation."])

    case choice do
      1 -> ask_about_guarana(ctx)
      2 -> reminisce(ctx)
      _ -> ctx
    end
  end

  defp reminisce(ctx),
    do: ctx |> mes("[Candy Maker]") |> mes("Those were the good 'ole days...") |> close()

  defp ask_about_guarana(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Candy Maker]")
      |> mes("Hmm? I already sold out of all my old supply.")
      |> next()
      |> mes("[Candy Maker]")
      |> mes("But if you can find some guarana, I can make it for you.")
      |> next()
      |> select(["How do I find guarana?", "End conversation."])

    case choice do
      1 ->
        introduce_cherto(ctx)

      2 ->
        ctx |> mes("[Candy Maker]") |> mes("Don't you want to try the guarana candy?") |> close()

      _ ->
        ctx
    end
  end

  defp introduce_cherto(ctx) do
    ctx
    |> mes("[Candy Maker]")
    |> mes("Will you find the guarana?? Hoooooh~")
    |> next()
    |> mes("[Candy Maker]")
    |> mes("Can you find it?")
    |> mes("It's probably very expensive.")
    |> mes("Trading isn't my thing. Let me think.")
    |> next()
    |> mes("[Candy Maker]")
    |> mes("Let me introduce you to someone with whom I used to do guarana business with.")
    |> mes("He might still be dealing it.")
    |> next()
    |> mes("[Candy Maker]")
    |> mes("His name is Cherto.")
    |> mes("If you can't find him in the city, go to museum.")
    |> mes("He's a vain person so he likes to act big.")
    |> mes("He's probably wandering in the museum trying to show off to someone for sure.")
    |> set_char_var(:brazil_gua, 1)
    |> setquest(2192)
    |> close()
  end

  defp finish_quest(ctx) do
    if not Rathena.truthy?(count_item(ctx, 6237)) do
      ctx |> mes("- The guarana that I had has disappeared. -") |> close()
    else
      make_candy(ctx)
    end
  end

  defp make_candy(ctx) do
    ctx =
      ctx
      |> delitem(6237, 1)
      |> mes("[Candy Maker]")
      |> mes("Did you get the guarana?")
      |> next()
      |> mes("- You give the guarana to him. -")
      |> next()
      |> mes("[Candy Maker]")
      |> mes("Wow! You have special talent.")
      |> mes("It's the best thing I have ever seen so far. Cool~!")
      |> next()
      |> mes("[Candy Maker]")
      |> mes("Good, let's make the candy~!")
      |> mes("Long time no see my wonderful guarana candy...")
      |> next()
      |> mes("- hash hash hash hash hash hash -")
      |> mes("- hash hash hash hash hash hash -")
      |> next()
      |> mes("[Candy Maker]")
      |> mes("Look! It's the popular guarana candy.")
      |> mes("Try to savor its amazing taste hey~ take it easy. hahaha!!")
      |> set_char_var(:brazil_gua, 11)
      |> completequest(2200)
      |> give_item(12_414, 1)

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        if Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) and
             Rathena.truthy?(vip_status(ctx, 1)) do
          getexp(ctx, 105_000, 15_000)
        else
          getexp(ctx, 70_000, 10_000)
        end
      else
        ctx
      end

    close(ctx)
  end

  defp offer_candy(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Candy Maker]")
      |> mes("Guarana candy. That was the most unique masterpiece in my life for sure!")
      |> next()
      |> mes("[Candy Maker]")
      |> mes("Since you helped me, guarana supply has been steadily rising.")
      |> mes("So, naturally I'm back to making guarana candy.")
      |> next()
      |> mes("[Candy Maker]")
      |> mes("What about it? Wanna buy some?")
      |> mes("It's 4000 zeny each.")
      |> next()
      |> select(["Buy a Guarana Candy.", "Cancel."])

    case choice do
      1 ->
        buy_candy(ctx)

      2 ->
        ctx
        |> mes("[Candy Maker]")
        |> mes("Sometimes some people don't like it due to it's arousal effect.")
        |> close()

      _ ->
        ctx
    end
  end

  defp buy_candy(ctx) do
    if zeny(ctx) > 3999 do
      ctx
      |> mes("[Candy Maker]")
      |> mes("Here is a delicious guarana candy.")
      |> pay_zeny(4000)
      |> give_item(12_414, 1)
      |> close()
    else
      ctx
      |> mes("[Candy Maker]")
      |> mes("What? You should say before if you don't have money!")
      |> mes("Even if you are poor, I can't give this away for free.")
      |> close()
    end
  end
end
