defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Lachellen do
  @moduledoc """
  Bruspetti’s friend, who shares clues about her disappearance.

  ## Behavior

  - Answers questions about Bruspetti and advances the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "rachel", x: 73, y: 244, dir: 3, sprite: 919, name: "Lachellen", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rach_vice, 0)

    cond do
      stage > 21 -> later_visit(ctx)
      stage in [11, 12] -> answer_question(ctx)
      stage == 7 -> directions(ctx)
      stage == 6 -> perfume_clue(ctx)
      stage in [2, 3] -> boyfriend_clue(ctx)
      true -> greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp later_visit(ctx) do
    ctx
    |> mes("[Lachellen]")
    |> mes("If you happen to see")
    |> mes("Bruspetti, tell her to")
    |> mes("come talk to me. I need")
    |> mes("to know whether I figured")
    |> mes("out who her boyfriend is!")
    |> mes("I can't wait to see her~")
    |> close()
  end

  defp directions(ctx) do
    ctx
    |> mes("[Lachellen]")
    |> mes("Let's see... Bruspetti")
    |> mes("and her guy would usually")
    |> mes("meet at... Um, I know where")
    |> mes("it is by feel, but I can't really")
    |> mes("give you good directions")
    |> mes("to get there. Er, sorry!")
    |> next()
    |> mes("[Lachellen]")
    |> mes("Luckily, this town")
    |> mes("isn't that big, so I'm")
    |> mes("sure you'll find something")
    |> mes("if you just keep looking.")
    |> mes("Oh, and if you find her,")
    |> mes("tell her I said ''hi,'' okay?")
    |> close()
  end

  defp perfume_clue(ctx) do
    ctx
    |> mes("[Lachellen]")
    |> mes("Oh, Bruspetti's dad")
    |> mes("was talking about how")
    |> mes("good she smells? Yeah,")
    |> mes("she's kinda famous for")
    |> mes("that around here, so he's")
    |> mes("not creepy or anything.")
    |> next()
    |> mes("[Lachellen]")
    |> mes("I see, so you think you")
    |> mes("caught wind of her in some")
    |> mes("other town. Yeah, I heard")
    |> mes("that she went traveling to see")
    |> mes("if she could learn something,")
    |> mes("and she hasn't returned yet.")
    |> next()
    |> mes("[Lachellen]")
    |> mes("Oh, you know what?")
    |> mes("If she's in Lighthalzen,")
    |> mes("she's probably gone there to")
    |> mes("learn more about her boyfriend.")
    |> mes("Bruspetti mentioned something")
    |> mes("about that when I last saw her.")
    |> next()
    |> mes("[Lachellen]")
    |> mes("I don't know anything")
    |> mes("else. Hmm, maybe if you")
    |> mes("check the place where she")
    |> mes("and her boyfriend usually")
    |> mes("went on dates, you might")
    |> mes("be able to find something.")
    |> set_char_var(:rach_vice, 7)
    |> changequest(8110, 8111)
    |> close()
  end

  defp boyfriend_clue(ctx) do
    ctx
    |> mes("[Lachellen]")
    |> mes("Ooh, I'm so jealous")
    |> mes("of Bruspetti! She's been")
    |> mes("spending so much time with")
    |> mes("her new boyfriend recently...")
    |> mes("But she still refuses to tell")
    |> mes("me what his name is.")
    |> next()
    |> mes("[Lachellen]")
    |> mes("She told me that she's")
    |> mes("serious about him, but")
    |> mes("she's also admitted that")
    |> mes("she doesn't know much about")
    |> mes("him. Let's see... He grew up in Lighthalzen? That's all she knows.")
    |> set_char_var(:rach_vice, 3)
    |> changequest(8106, 8107)
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Lachellen]")
    |> mes("My friend Bruspetti")
    |> mes("is a really nice girl~")
    |> mes("Everyone loves her, and")
    |> mes("she's sooo beautiful. All")
    |> mes("the guys are jealous of")
    |> mes("her new boyfriend!")
    |> next()
    |> mes("[Lachellen]")
    |> mes("Still, she's really")
    |> mes("shy, and won't tell me")
    |> mes("who he is. There's a lot")
    |> mes("I don't know about him, but")
    |> mes("I'm sure they're happy together.")
    |> close()
  end

  defp answer_question(ctx) do
    {ctx, question} =
      ctx
      |> mes("[Lachellen]")
      |> mes("Oh, hello again~")
      |> mes("Is there any way I can")
      |> mes("help you this time? I know")
      |> mes("you're looking for Bruspetti,")
      |> mes("so I'll help you if you have")
      |> mes("any questions for me~")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", question)

    case get_local(ctx, :"input$", "") do
      "Lighthalzen" ->
        ctx =
          ctx
          |> mes("[Lachellen]")
          |> mes("Lighthalzen? Oh, that's")
          |> mes("right! Bruspetti did ask")
          |> mes("me about Lighthalzen a while")
          |> mes("ago. Yes, she seemed really")
          |> mes("interested in learning more")
          |> mes("about that place recently.")
          |> next()

        finish_answer(ctx)

      "Freya's Spring" ->
        ctx =
          ctx
          |> mes("[Lachellen]")
          |> mes("Freya's Spring?")
          |> mes("Oh, I like that place!")
          |> mes("Speaking of which, I know")
          |> mes("someone named Katinshuell")
          |> mes("that went there pretty often.")
          |> mes("Usually men don't go alone...")
          |> next()
          |> mes("[Lachellen]")
          |> mes("Wait, that's the place")
          |> mes("I told you about, where")
          |> mes("Bruspetti and her boyfriend")
          |> mes("usually met. Do you think")
          |> mes("she and Katinshuell...?")
          |> mes("Ooh, maybe I figured it out!")
          |> next()
          |> mes("[Lachellen]")
          |> mes("But yeah, that place is")
          |> mes("usually filled with couples,")
          |> mes("so you look like a real loser")
          |> mes("if you go there alone. That's")
          |> mes("why I want a boyfriend now...")
          |> set_char_var(:rach_vice, 12)
          |> changequest(8115, 8116)
          |> next()

        finish_answer(ctx)

      _ ->
        ctx
        |> mes("[Lachellen]")
        |> mes("Oh, I'm sorry...")
        |> mes("I don't know anything")
        |> mes(Rathena.concat(Rathena.concat("about ", get_local(ctx, :"input$", "")), "."))
        |> close()
    end
  end

  defp finish_answer(ctx) do
    ctx
    |> mes("[Lachellen]")
    |> mes("Well, I don't know if")
    |> mes("you learned anything")
    |> mes("important from me,")
    |> mes("but I hope I helped")
    |> mes("you, even if it was")
    |> mes("just a little bit.")
    |> close()
  end
end
