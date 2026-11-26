defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Belder do
  @moduledoc """
  Belder runs a loan business in Alberta.

  ## Behavior

  - His dialogue and advertisements change as the debt investigation progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 127, y: 143, dir: 3, sprite: 85, name: "Belder", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    debt = get_char_var(ctx, :diamond_edq, 0)

    cond do
      debt == 0 ->
        promotion(ctx)

      debt < 13 ->
        ask_about_muff(ctx)

      debt > 12 ->
        debt_found(ctx)

      true ->
        ctx
        |> mes("[Belder]")
        |> mes("Welcome! Did you need")
        |> mes("money fa--Oh. Hey, it's")
        |> mes("you again, the do-gooder.")
        |> mes("Why don't you do me some")
        |> mes("good, and go back where")
        |> mes("you came from. Jerk.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp promotion(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Belder]")
      |> mes("I ought to hire some")
      |> mes("part-time promotional")
      |> mes("workers... Some sexy")
      |> mes("ladies ought to bring in")
      |> mes("the customers by th--Oh!")
      |> mes("Welcome to Belder Loans!")
      |> next()
      |> select(["I'll promote your loans!", "Uh..."])

    case choice do
      1 ->
        if sex(ctx) == 1 do
          ctx
          |> mes("[Belder]")
          |> mes("You? But you're a dude!")
          |> mes("No sweaty, stinky, sleazy")
          |> mes("man should be the image")
          |> mes("of Belder Loans! We need")
          |> mes("to exude trust, dependability,")
          |> mes("and... And lady charms.")
          |> close()
        else
          ctx
          |> mes("[Belder]")
          |> mes("You? Well, don't take")
          |> mes("this the wrong way, but")
          |> mes("all your curves? Wrong")
          |> mes("places, honey. Later!")
          |> close()
        end

      2 ->
        ctx
        |> mes("[Belder]")
        |> mes("Hey, aren't you")
        |> mes("interested in a loan?")
        |> mes("Better you come to")
        |> mes("me than you relying")
        |> mes("on some guy that'll")
        |> mes("try to rip you off!")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_about_muff(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Belder]")
      |> mes("Welcome! So, do you")
      |> mes("need money fast? Belder")
      |> mes("Loans get you the money")
      |> mes("you need at low interest rates!")
      |> next()
      |> select(["Ask About Muff"])

    case choice do
      1 ->
        ctx
        |> mes("[Belder]")
        |> mes("Muff? Oh! Is that")
        |> mes("supposed to be a name?")
        |> mes("I thought you meant--No.")
        |> mes("Nope. Doesn't ring a bell.")
        |> next()
        |> mes("[Belder]")
        |> mes("Huh? Collateral?")
        |> mes("Now why would I refuse")
        |> mes("to take back his money")
        |> mes("if I really loaned it to him?")
        |> mes("Leave me alone now, this kind")
        |> mes("of talk is bad for business!")
        |> close()

      _ ->
        ctx
    end
  end

  defp debt_found(ctx) do
    ctx =
      ctx
      |> mes("[Belder]")
      |> mes("He really found his bond")
      |> mes("of debt? Damn it--I mean,")
      |> mes("what a surprise! That's,")
      |> mes("uh, real good for him.")
      |> mes("Now that I think of it, I did")
      |> mes("loan a Muff money once.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("......")
    |> next()
    |> mes("[Belder]")
    |> mes("What's with that dirty look?")
    |> mes("I've got nothing to hide!")
    |> mes("Can't you see that I'm")
    |> mes("the victim here? Me!")
    |> mes("Just... Scram before you")
    |> mes("make me more upset.")
    |> close()
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :diamond_edq, 0) < 3 do
      ctx
      |> mes("[Belder]")
      |> mes("Cash flow problems?")
      |> mes("Well, I'm your solution!")
      |> mes("I offer unsecured loans")
      |> mes("at an extremely low interest")
      |> mes("rate, twenty-four hours a day!")
      |> mes("Belder Loans is Alberta's best!")
      |> close()
    else
      ctx
    end
  end
end
