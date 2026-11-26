defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Kid do
  @moduledoc """
  Rooney seeks help finding the recipient of a letter.

  ## Behavior

  - Asks the player to locate a bard and later accepts his delivery payment.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 202,
        y: 122,
        dir: 0,
        sprite: 703,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :que_sch, 0) do
      0 -> offer_help(ctx)
      1 -> find_bard_reminder(ctx)
      2 -> delivery_payment(ctx)
      _ -> ctx |> mes("[Rooney]") |> mes("Nice day out, isn't it?") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_help(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Rooney]")
      |> mes("Where the heck")
      |> mes("is it? I don't... Where...?")
      |> mes("He's got to be around here")
      |> mes("somewhere, I think...")
      |> next()
      |> select(["What's wrong?", "..."])

    {ctx, choice} =
      ctx
      |> mes("[Rooney]")
      |> mes("Oh, it's just...")
      |> mes("Some guy sent me on a")
      |> mes("delivery errand, but I can't")
      |> mes("find the recipient. He said")
      |> mes("that I can't miss him, but")
      |> mes("I still can't figure it out.")
      |> next()
      |> mes("[Rooney]")
      |> mes("I should have asked for")
      |> mes("the exact location. I mean,")
      |> mes("if I don't find him, then I'll")
      |> mes("never get paid for doing")
      |> mes("this delivery. ^333333*Sigh*^000000")
      |> next()
      |> select(["Sounds tough. Good luck!", "Do you need any help?"])

    if choice == 1 do
      ctx
      |> mes("[Rooney]")
      |> mes("Thanks. I think")
      |> mes("I just might need it.")
      |> mes("Where could this guy")
      |> mes("be? If he's expecting")
      |> mes("a delivery, he should")
      |> mes("make himself easy to find...")
      |> close()
    else
      ctx
      |> mes("[Rooney]")
      |> mes("Yeah, sure, it'd be great")
      |> mes("if you could help me. Let's")
      |> mes("see, I need to deliver this")
      |> mes("letter to a bard named...")
      |> mes("It was... Ah, ^FF0000Lasda Midar^000000!")
      |> next()
      |> mes("[Rooney]")
      |> mes("I've looked everywhere")
      |> mes("in town for someone that")
      |> mes("looks like a Bard, but I'm")
      |> mes("not having any luck. If you")
      |> mes("find him, would you tell me?")
      |> set_char_var(:que_sch, 1)
      |> close()
    end
  end

  defp find_bard_reminder(ctx) do
    ctx
    |> mes("[Rooney]")
    |> mes("I still haven't")
    |> mes("found Lasda Midar.")
    |> mes("Would you let me know")
    |> mes("if you find him so that")
    |> mes("I can deliver his letter?")
    |> close()
  end

  defp delivery_payment(ctx) do
    if zeny(ctx) < 100 do
      ctx
      |> mes("[Rooney]")
      |> mes("Lasda Midar...")
      |> mes("Where the heck")
      |> mes("could that guy be?")
      |> close()
    else
      {ctx, _} =
        ctx
        |> mes("[Rooney]")
        |> mes("Wow, did you really")
        |> mes("find Lasda Midar?")
        |> mes("Why couldn't I find him?")
        |> mes("Anyway, thank you so much")
        |> mes("for your help. I thought I was")
        |> mes("going to fail my delivery!")
        |> next()
        |> select(["He asked me to give you this."])

      ctx
      |> mes("[Rooney]")
      |> mes("Hey, alright! Thanks")
      |> mes("for the cash! Heh heh~")
      |> pay_zeny(100)
      |> set_char_var(:que_sch, 3)
      |> close()
    end
  end
end
