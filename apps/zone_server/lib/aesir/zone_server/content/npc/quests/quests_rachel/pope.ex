defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Pope do
  @moduledoc """
  The pope speaks with adventurers visiting her chamber.

  ## Behavior

  - Discusses the Holy Ground and advances the sanctuary investigation.
  - Responds to visitors during the Peace for Arunafeltz quest.

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
      %{
        map: "ra_temsky",
        x: 99,
        y: 99,
        dir: 5,
        sprite: 936,
        name: "Pope",
        scope: :shared,
        unique_name: "Pope#rachel"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ra_tem_q, 0) == 16 -> first_audience(ctx)
      get_char_var(ctx, :aru_em, 0) < 15 -> zhed_reminder(ctx)
      get_char_var(ctx, :aru_em, 0) == 15 -> return_audience(ctx)
      true -> later_visit(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp first_audience(ctx) do
    {ctx, _} =
      ctx
      |> cutin("ra_bishop", 2)
      |> mes("^3355FFTh-this little")
      |> mes("girl is the pope...?!^000000")
      |> next()
      |> mes("[Pope]")
      |> mes("...............................")
      |> mes("..........................Um...")
      |> mes("W-welcome. Is something")
      |> mes("wrong? Oh, I know, it's my")
      |> mes("eyes. I'm sorry if they")
      |> mes("scare you a little bit.")
      |> next()
      |> select(["No, not at all...!"])

    ctx =
      ctx
      |> mes("[Pope]")
      |> mes("......")
      |> mes("......")
      |> mes("......You know, my appearance...")
      |> next()
      |> mes("[Pope]")
      |> mes("It's alright. Actually,")
      |> mes("I'm used to it. People")
      |> mes("are usually a little shocked")
      |> mes("the first time they see me.")
      |> mes("So... Um... Where do you")

    {ctx, home} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("come from, ", char_name(ctx, 0)), "?"))
      |> next()
      |> input(:string)

    ctx = ctx |> set_temp_var(:"input$", home) |> mes("[Pope]")

    {ctx, occupation} =
      ctx
      |> mes(Rathena.concat(get_temp_var(ctx, :"input$", ""), "...?"))
      |> mes("I think I might have heard")
      |> mes("about that place before.")
      |> mes("Wow... What did you do")
      |> mes("when you lived there?")
      |> next()
      |> input(:string)

    ctx = ctx |> set_temp_var(:"input$", occupation) |> mes("[Pope]")

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(get_temp_var(ctx, :"input$", ""), "...?"))
      |> mes("Wow, that sounds quite")
      |> mes("extraordinary. Ooh, ooh!")
      |> mes("Tell me, how have you come")
      |> mes("here to Rachel? I'm interested")
      |> mes("in knowing more about you~")
      |> next()
      |> mes("^3355FFYou and the pope")
      |> mes("continued to comfortably")
      |> mes("converse. As she spoke, she")
      |> mes("seemed more like a young,")
      |> mes("lonely girl than a solemn")
      |> mes("religious figure for a nation.^000000")
      |> next()
      |> mes("[Pope]")
      |> mes("...Wow, sometimes, I really")
      |> mes("wish I could live like you.")
      |> mes("You'd think being pope would")
      |> mes("be great, but they make me work")
      |> mes("all the time. And there are all")
      |> mes("sorts of things I can't do.")
      |> next()
      |> mes("[Pope]")
      |> mes("You know what's weird?")
      |> mes("I think I'm the head of this")
      |> mes("religion, but there's a sacred")
      |> mes("place that even I'm not allowed")
      |> mes("to visit. Isn't that so weird?")
      |> next()
      |> select(["R-really...?"])

    {ctx, _} =
      ctx
      |> mes("[Pope]")
      |> mes("...Yeah. I don't know")
      |> mes("much about, and I'm not")
      |> mes("really supposed to talk")
      |> mes("about it. We just call this")
      |> mes("place the ''Holy Ground...''")
      |> next()
      |> select(["Holy Ground?"])

    ctx =
      ctx
      |> mes("[Pope]")
      |> mes("I'm sorry... I want")
      |> mes("to tell you more, but...")
      |> mes("That's all I know. I wonder...")
      |> mes("I wonder what they could")
      |> mes("be hiding over there...")
      |> next()
      |> mes("[Priest]")
      |> mes("I'm sorry to interrupt")
      |> mes("your Excellency, but it's")
      |> mes("time to officiate services.")
      |> mes("Pardon me.")
      |> next()
      |> mes("[Pope]")
      |> mes("Already?! Hmpf...")
      |> mes("Oh, before I forget,")
      |> mes("I needed to tell you that")
      |> mes("High Priest Zhed wanted")

    ctx
    |> mes(Rathena.concat(Rathena.concat("to talk to you, ", char_name(ctx, 0)), "."))
    |> next()
    |> mes("[Pope]")
    |> mes("I really want to thank")
    |> mes("you for coming to speak")
    |> mes("to me. I had a great time")
    |> mes("learning. Now I have to")
    |> mes("go officiate services, so...")
    |> mes("This is goodbye for now...")
    |> close2()
    |> cutin("", 255)
    |> set_char_var(:ra_tem_q, 17)
    |> changequest(8100, 8101)
  end

  defp zhed_reminder(ctx) do
    ctx
    |> mes("[Pope]")
    |> mes("Oh, that's right...")
    |> mes("Zhed... Er, High Priest")
    |> mes("Zhed wanted to speak to you!")
    |> close2()
    |> cutin("", 255)
  end

  defp return_audience(ctx) do
    {ctx, story} =
      ctx
      |> mes("[Pope]")
      |> mes("Oh, hello! It's you again!")
      |> mes("Have you come to tell me")
      |> mes("interesting stories about")
      |> mes("the outside world again?")
      |> next()
      |> input(:string)

    ctx =
      ctx
      |> set_local(:"input$", story)
      |> mes("[Pope]")
      |> mes("Mm. That sounds pretty")
      |> mes("strange to me. Well, it's")
      |> mes("good to hear it from you.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("(^333333I can't just leave")
      |> mes("now. I should try to see")
      |> mes("if I can learn anything")
      |> mes("useful from the pope...^000000)")
      |> next()
      |> select(["Aren't you lonely?", "Do you ever take a break?"])

    case choice do
      1 -> lonely(ctx)
      2 -> break_time(ctx)
      _ -> ctx
    end
  end

  defp lonely(ctx) do
    ctx
    |> mes("[Pope]")
    |> mes("Well, there are always")
    |> mes("some priests with me all")
    |> mes("the time. Some of them")
    |> mes("even watch me when I sleep.")
    |> mes("I don't think I have time")
    |> mes("to feel lonely, actually.")
    |> next()
    |> mes("[Pope]")
    |> mes("Thank you for asking.")
    |> mes("Sometimes... Sometimes")
    |> mes("I wonder if I have a real")
    |> mes("family. I don't even know")
    |> mes("who'd they be or if they")
    |> mes("exist. I don't know...")
    |> next()
    |> mes("[Pope]")
    |> mes("I... I'm sorry.")
    |> mes("I guess you didn't")
    |> mes("expect to hear something")
    |> mes("like that. ^666666*Sigh*^000000 I'm feeling")
    |> mes("pretty exhausted. I better...")
    |> mes("I better get some rest...")
    |> set_char_var(:aru_em, 16)
    |> changequest(2135, 2136)
    |> close2()
    |> cutin("", 255)
  end

  defp break_time(ctx) do
    ctx
    |> mes("[Pope]")
    |> mes("Well, even if I wanted")
    |> mes("to, I can't just go out")
    |> mes("and play. As pope... Well...")
    |> mes("Everyone and everything")
    |> mes("sort of needs my attention.")
    |> close2()
    |> cutin("", 255)
  end

  defp later_visit(ctx) do
    ctx =
      if get_char_var(ctx, :aru_em, 0) == 16 do
        ctx
        |> mes("[Follower]")
        |> mes("The pope said that she's")
        |> mes("exhausted. Please come")
        |> mes("back when she's feeling")
        |> mes("better, and she will have")
        |> mes("an audience with you.")
      else
        ctx
      end

    ctx |> close2() |> cutin("", 255)
  end
end
