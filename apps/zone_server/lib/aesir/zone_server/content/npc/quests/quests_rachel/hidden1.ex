defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Hidden1 do
  @moduledoc """
  Lets the adventurer overhear the priests and meet Niren.

  ## Behavior

  - Reveals the conversation and advances the sanctuary quest and quest log.

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
        map: "ra_temin",
        x: 288,
        y: 151,
        dir: 0,
        sprite: -1,
        name: "hidden1",
        scope: :shared,
        unique_name: "hidden1#rachel",
        trigger: {1, 6}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ra_tem_q, 0) == 18 do
      {ctx, _} =
        ctx
        |> mes("^3355FFAt this distance you")
        |> mes("can cleartly hear the")
        |> mes("voices from the other")
        |> mes("side of the wall...^000000")
        |> next()
        |> mes("[????]")
        |> mes("...Was it really")
        |> mes("necessary to involve")
        |> mes("an outsider in this")
        |> mes("situation? Answer me!")
        |> next()
        |> mes("[High Priest Zhed]")
        |> mes("Is this about the")
        |> mes("accident? You know that")
        |> mes("I've disagreed with the")
        |> mes("actions that have led to")
        |> mes("the mana leakage.")
        |> next()
        |> mes("[High Priest Zhed]")
        |> mes("Even though I thought")
        |> mes("it was a reckless decision,")
        |> mes("I've closed the shrine and")
        |> mes("did my best to cover up this")
        |> mes("unfortunate accident.")
        |> next()
        |> mes("[????]")
        |> mes("I'm not blaming you. In")
        |> mes("fact, I'll admit it: that was")
        |> mes("our mistake. We caused")
        |> mes("the monster infestation by")
        |> mes("letting the mana leak.")
        |> next()
        |> mes("[????]")
        |> mes("But that's not related")
        |> mes("to what I'm asking you!")
        |> mes("Do you really think it's")
        |> mes("alright to allow an outsider")
        |> mes("to speak to our pope during")
        |> mes("such a tumultuous time?!")
        |> next()
        |> mes("[High Priest Zhed]")
        |> mes("Why not? I thought it'd")
        |> mes("bring her great comfort.")
        |> mes("She is very confused as to")
        |> mes("why the Holy Ground has been")
        |> mes("closed, and she cannot know")
        |> mes("what is happening there.")
        |> next()
        |> mes("[High Priest Zhed]")
        |> mes("Again... I strongly")
        |> mes("disagree with what is")
        |> mes("secretly going on over")
        |> mes("there. I know that I can't")
        |> mes("officially oppose this")
        |> mes("course of action, but...")
        |> next()
        |> mes("[????]")
        |> mes("There's nothing to worry")
        |> mes("about! It'll all be over before")
        |> mes("you know it. Besides, it's")
        |> mes("too late to turn back now,")
        |> mes("so I warn you: don't you")
        |> mes("dare do anything foolish.")
        |> next()
        |> mes("^3355FFSomeone's coming!")
        |> mes("You'd better step away")
        |> mes("from the wall and feign")
        |> mes("ignorance as best you can!^000000")
        |> next()
        |> hideoffnpc("High Priestess Niren#ra")
        |> cutin("ra_gwoman", 2)
        |> mes("[High Priestess Niren]")
        |> mes("Oh! You must be the one")
        |> mes("High Priest Be- er, Zhed,")
        |> mes("told me about. It's very nice")
        |> mes("to meet you. High Priestess")
        |> mes("Niren, at your service.")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("I hear that you had the")
        |> mes("privilege of speaking with")
        |> mes("our pope, and that she had")
        |> mes("a wonderful time. What did")
        |> mes("you think of her, hm?")
        |> next()
        |> select(["She's different than what I expected..."])

      ctx =
        ctx
        |> cutin("ra_gwoman2", 2)
        |> mes("[High Priestess Niren]")
        |> mes("Ah, I know what you mean...")
        |> mes("Usually, most outsiders tell")
        |> mes("me that they expect our pope")
        |> mes("to be a wizened old man.")
        |> mes("But that's not the case")
        |> mes("here in Arunafeltz.")
        |> next()
        |> cutin("ra_gwoman", 2)
        |> mes("[High Priestess Niren]")
        |> mes("Usually, our pope is chosen")
        |> mes("by her resemblance to our")
        |> mes("goddess Freya. She must")
        |> mes("have silvery blond hair, snowy")
        |> mes("skin, and divinely colored")
        |> mes("eyes. You saw, didn't you?")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("I'm curious: what kinds")
        |> mes("of things did you and the")
        |> mes("pope talk about? As you know,")
        |> mes("we priests are forbidden from")
        |> mes("leaving Arunafeltz, so...")
        |> next()
        |> mes("^3355FFYou relate the details of")
        |> mes("your talk with the pope, but")
        |> mes("you make sure not to mention")
        |> mes("anything about the Holy Ground")
        |> mes("as High Priest Zhed had asked.^000000")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("Ah, that's fairly")
        |> mes("interesting, your land.")
        |> mes("Tell me, how did you come")
        |> mes("to know Bekento, er, I mean,")
        |> mes("High Priest Zhed?")
        |> next()

      {ctx, _} =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("(^666666Bekento?^000000)")
        |> next()
        |> select(["Explain how You Met High Priest Zhed"])

      ctx =
        ctx
        |> cutin("ra_gwoman2", 2)
        |> mes("[High Priestess Niren]")
        |> mes(".........................")
        |> mes("That's all? Hm? That's")
        |> mes("pretty funny. ^333333*Sigh*^000000 I believe")
        |> mes("he trusts people too much...")
        |> mes("But that's only my opinion.")
        |> next()
        |> cutin("ra_gwoman", 2)
        |> mes("[High Priestess Niren]")
        |> mes("If you don't mind...")
        |> mes("I want to give you a bit of")
        |> mes("advice. Don't get too close")
        |> mes("to High Priest Zhed. If you")
        |> mes("do, you might end up getting")
        |> mes("yourself in trouble.")
        |> next()
        |> cutin("", 255)
        |> hideonnpc("High Priestess Niren#ra")
        |> mes("^3355FFHigh Priestess Niren left")
        |> mes("as soon as she said those words.")
        |> mes("What could she possibly mean?")
        |> mes("For now, you may as well")
        |> mes("talk to High Priest Zhed.^000000")
        |> set_char_var(:ra_tem_q, 19)

      ctx =
        cond do
          isbegin_quest(ctx, 8102) == 1 -> changequest(ctx, 8102, 8103)
          isbegin_quest(ctx, 8101) == 1 -> changequest(ctx, 8101, 8103)
          true -> ctx
        end

      close(ctx)
    else
      ctx
    end
  end
end
