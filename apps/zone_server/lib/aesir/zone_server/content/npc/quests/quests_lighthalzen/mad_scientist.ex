defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.MadScientist do
  @moduledoc """
  Wolfchev demands a glass bead before discussing his research.

  ## Behavior

  - Requests a bead and reveals hints about his experiments.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 273,
        y: 121,
        dir: 1,
        sprite: 865,
        name: "Mad Scientist",
        scope: :shared,
        unique_name: "Mad Scientist#li"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_curse, 0) do
      13 -> first_meeting(ctx)
      14 -> request_help(ctx)
      15 -> if count_item(ctx, 746) > 0, do: deliver_bead(ctx), else: bead_reminder(ctx)
      _ -> ctx
    end
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Wolfchev]")
      |> mes("No one shall")
      |> mes("interrupt my")
      |> mes("research! If you")
      |> mes("dare, I'll simply...")
      |> mes("Eat you. Eat you alive.")
      |> next()
      |> select(["No... N-no!", "Do you need any help?"])

    case choice do
      1 ->
        ctx
        |> mes("[Wolfchev]")
        |> mes("Out of my sight,")
        |> mes("microcephalic fool!")
        |> close()

      2 ->
        ctx
        |> mes("[Wolfchev]")
        |> mes("Huh? You think I have")
        |> mes("the luxury of remembering")
        |> mes("the face of every part-timer")
        |> mes("I've fired? Get lost, or I'll")
        |> mes("treat you to the pain of")
        |> mes("being eaten alive!")
        |> set_char_var(:lhz_curse, 14)
        |> close()

      _ ->
        ctx
    end
  end

  defp request_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Wolfchev]")
      |> mes("You again?!")
      |> mes("What the hell do")
      |> mes("you want from me?!")
      |> emotion(:anger)
      |> next()
      |> select(["Let me speak with you.", "Sorry for bothering you."])

    case choice do
      1 ->
        ctx
        |> mes("[Wolfchev]")
        |> mes("I don't have time to")
        |> mes("waste with drivel! I'm")
        |> mes("too busy with my research!")
        |> next()
        |> mes("[Wolfchev]")
        |> mes("...........!")
        |> emotion(:surprise)
        |> next()
        |> mes("[Wolfchev]")
        |> mes("Ah, but wait! I am collecting")
        |> mes("something. Yes, bring me the")
        |> mes("thing I must collect. Yes, yes.")
        |> mes("Here's a hint... It's round...")
        |> mes("Shiny... Kids love playing games with them! Oh, I said too much!")
        |> set_char_var(:lhz_curse, 15)
        |> changequest(2089, 2090)
        |> close()

      2 ->
        ctx
        |> emotion(:fret)
        |> mes("[Wolfchev]")
        |> mes("''Sorry?!'' Do you")
        |> mes("think ''sorry'' will")
        |> mes("get back that precious")
        |> mes("minute I've lost yelling")
        |> mes("at you?! Get the hell out!")
        |> close()

      _ ->
        ctx
    end
  end

  defp deliver_bead(ctx) do
    {ctx, choice} =
      ctx
      |> delitem(746, 1)
      |> mes("[Wolfchev]")
      |> mes("Yes...! Beads!")
      |> mes("You brought them!")
      |> mes("You're not as dumb")
      |> mes("as I thought you'd be!")
      |> next()
      |> select(["Why do you want Glass Beads?"])

    case choice do
      1 -> bead_explanation(ctx)
      _ -> ctx
    end
  end

  defp bead_explanation(ctx) do
    ctx =
      ctx
      |> mes("[Wolfchev]")
      |> mes("..................")
      |> mes("I take that back!")
      |> mes("You should know by")
      |> mes("now that I would never")
      |> mes("tell you why I neeeeed")
      |> mes("these Beads. Bweh-heh!")
      |> emotion(:kik)
      |> next()

    ctx =
      ctx
      |> mes("[Wolfchev]")
      |> mes("This favor you've done")
      |> mes("is worth a small chat and")
      |> mes("I can spare a minute or two")
      |> mes("for you inane questions. So")
      |> mes("what is it you want to know?!")
      |> next()

    discuss_hobbies_or_work(ctx)
  end

  defp discuss_hobbies_or_work(ctx) do
    {ctx, choice} = select(ctx, ["Ask about hobbies", "Ask about work"])

    case choice do
      1 ->
        ctx = hobby(ctx)

        if Rathena.truthy?(get_local(ctx, :exit, 0)),
          do: ask_research(ctx),
          else: discuss_hobbies_or_work(ctx)

      2 ->
        ctx = work(ctx)

        if Rathena.truthy?(get_local(ctx, :exit, 0)),
          do: ask_research(ctx),
          else: discuss_hobbies_or_work(ctx)

      _ ->
        ctx
    end
  end

  defp hobby(ctx) do
    if sex(ctx) == 1 do
      ctx
      |> mes("[Wolfchev]")
      |> mes("Hyuu~ I think you're")
      |> mes("just a little too innocent")
      |> mes("to know about my secret")
      |> mes("hobby. Yes, yes, I couldn't")
      |> mes("tell you possibly, it'd be")
      |> mes("so weird, so strange...")
      |> next()
    else
      ctx
      |> mes("[Wolfchev]")
      |> mes("Oh. Oh no, oh no,")
      |> mes("I couldn't possibly...")
      |> mes("It's a-- I-It's a secret.")
      |> mes("You wouldn't want to know")
      |> mes("anyway. Bweh-heh-heh-heh!")
      |> next()
    end
  end

  defp work(ctx) do
    ctx
    |> mes("[Wolfchev]")
    |> mes("Oh, I don't know if you")
    |> mes("can call it work. After all,")
    |> mes("I do research whatever it is")
    |> mes("I want. And they pay me to")
    |> mes("do it! This is the best place")
    |> mes("for a scientist like me, yes.")
    |> next()
    |> mes("[Wolfchev]")
    |> mes("Now, in a perfect world,")
    |> mes("my test subjects would be")
    |> mes("much more cooperative, but")
    |> mes("I suppose I cannot blame")
    |> mes("them. Not that I cause them")
    |> mes("undue suffering or anything...")
    |> next()
    |> set_local(:exit, 1)
  end

  defp ask_research(ctx) do
    {ctx, choice} = select(ctx, ["What kind of research?"])

    case choice do
      1 -> describe_research(ctx)
      _ -> ctx
    end
  end

  defp describe_research(ctx) do
    ctx =
      ctx
      |> mes("[Wolfchev]")
      |> mes("Well, I couldn't tell you")
      |> mes("exactly. But don't you")
      |> mes("worry, the discovery I'm")
      |> mes("working on will benefit the")
      |> mes("entire world, you'll see.")
      |> next()
      |> mes("[Wolfchev]")
      |> mes("Let's just say that once")
      |> mes("I'm successful, I'll satisfy")
      |> mes("one of mankind's most primal")
      |> mes("instincts, the desire to become")
      |> mes("powerful and gain dominance")
      |> mes("over those that are weaker.")
      |> next()
      |> mes("[Wolfchev]")
      |> mes("I haven't made as much")
      |> mes("progress as I'd like, but")
      |> mes("no matter. It's only a matter")
      |> mes("of experimentation! Yes, to")
      |> mes("make mankind stronger and")
      |> mes("better and more powerful and--")
      |> next()

    {ctx, _} = select(ctx, ["Um, what are you testing on?"])

    ctx
    |> mes("[Wolfchev]")
    |> mes("What do you know?")
    |> mes("I better get back to")
    |> mes("work if I wish to keep")
    |> mes("on schedule. I can't afford")
    |> mes("the leisure of speaking with")
    |> mes("you any longer. Bweh heh heh!")
    |> set_char_var(:lhz_curse, 16)
    |> close()
  end

  defp bead_reminder(ctx) do
    ctx
    |> mes("[Wolfchev]")
    |> mes("I don't have time to")
    |> mes("waste with drivel! I'm")
    |> mes("too busy with my research!")
    |> next()
    |> mes("[Wolfchev]")
    |> mes("...........!")
    |> emotion(:surprise)
    |> next()
    |> emotion(:kik)
    |> mes("[Wolfchev]")
    |> mes("Ah, but wait! I am collecting")
    |> mes("something. Yes, bring me the")
    |> mes("thing I must collect. Yes, yes.")
    |> mes("Here's a hint... It's round...")
    |> mes("Shiny... Kids love playing games with them! Oh, I said too much!")
    |> close()
  end
end
