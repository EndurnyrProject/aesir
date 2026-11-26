defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.PrisonWard do
  @moduledoc """
  Jesse guards the prison and controls access to its prisoner.

  ## Behavior

  - Requests a meal and approval before admitting the player.
  - Reacts to the prisoner’s escape and the investigation’s conclusion.

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
  - Fixed the unreachable second `que_sch < 19` branch to `que_sch < 25`.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 53,
        y: 87,
        dir: 7,
        sprite: 707,
        name: "Prison Ward",
        scope: :shared,
        unique_name: "Prison Ward#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 4 ->
        ctx
        |> mes("[Jesse]")
        |> mes("Only authorized")
        |> mes("personnel can enter")
        |> mes("this prison. You need")
        |> mes("a permit if you want")
        |> mes("to be able to enter.")
        |> close()

      stage == 4 ->
        ctx
        |> mes("[Jesse]")
        |> mes("What? You want to meet")
        |> mes("the prisoner? I'm sorry,")
        |> mes("but he's not allowed to")
        |> mes("see anyone since he was")
        |> mes("arrested on suspicion")
        |> mes("of espionage.")
        |> set_char_var(:que_sch, 5)
        |> close()

      stage == 5 ->
        ctx
        |> mes("[Jesse]")
        |> mes("Huh. You're awfully")
        |> mes("persistent. Alright,")
        |> mes("if you can do me a favor,")
        |> mes("I'll let you in. Bring me")
        |> mes("1 dish of ^FF0000Fried Monkey Tails^000000")
        |> next()
        |> mes("[Jesse]")
        |> mes("Of course, I can only let")
        |> mes("you inside. Whether they'll")
        |> mes("actually let you meet the")
        |> mes("prisoner is another matter.")
        |> mes("So do we have a deal?")
        |> set_char_var(:que_sch, 6)
        |> close()

      stage == 6 and count_item(ctx, 12066) > 0 ->
        ctx
        |> mes("[Jesse]")
        |> mes("Ah, that's the stuff!")
        |> mes("Thanks for the Fried")
        |> mes("Monkey Tails~ Alright,")
        |> mes("go talk to ^FF0000Sir Krieg^000000 in")
        |> mes("Morocc Castle. Get his")
        |> mes("approval, and I'll let you in.")
        |> delitem(12066, 1)
        |> set_char_var(:que_sch, 7)
        |> close()

      stage == 6 ->
        ctx
        |> mes("[Jesse]")
        |> mes("Bring me a plate of")
        |> mes("^FF0000Fried Monkey Tails^000000.")
        |> mes("Do it, or I won't help")
        |> mes("you out. I mean, I know")
        |> mes("you mean well, but I'm")
        |> mes("risking my job here...")
        |> close()

      stage < 10 ->
        ctx
        |> mes("[Jesse]")
        |> mes("You didn't get approval")
        |> mes("from Sir Krieg yet? You'd")
        |> mes("better do it, or there's no")
        |> mes("point in entering this prison.")
        |> mes("You can't just sneak around")
        |> mes("inside this place, you know?")
        |> close()

      stage == 10 ->
        ctx
        |> mes("[Jesse]")
        |> mes("Did you really get")
        |> mes("Sir Krieg's approval?")
        |> mes("Alright, you may enter now.")
        |> close2()
        |> warp("ra_in01", 48, 355)

      stage < 19 ->
        {ctx, choice} =
          ctx
          |> mes("[Jesse]")
          |> mes("Do you want to enter?")
          |> next()
          |> select(["Yes.", "No"])

        if choice == 1 do
          ctx
          |> mes("[Jesse]")
          |> mes("Be careful when you talk")
          |> mes("to that guy: he's a smooth")
          |> mes("talker, and almost charmed")
          |> mes("a lot of the guards into")
          |> mes("letting him go free.")
          |> close2()
          |> warp("ra_in01", 48, 355)
        else
          ctx
          |> mes("[Jesse]")
          |> mes("Take your time.")
          |> mes("If you're not mentally")
          |> mes("prepared, then it's not")
          |> mes("a good idea to talk")
          |> mes("to the prisoner.")
          |> close()
        end

      stage < 25 ->
        ctx
        |> mes("[Jesse]")
        |> mes("Argh, I'm in trouble.")
        |> mes("The prisoner escaped.")
        |> mes("How could I let this...")
        |> mes("happen?! Damn, I need to")
        |> mes("report this to Mr. Krieg")
        |> close()

      true ->
        ctx
        |> mes("[Jesse]")
        |> mes("What a relief! They")
        |> mes("really set it up so that")
        |> mes("the prisoner could escape?")
        |> mes("Well, I thought I was going")
        |> mes("to get fired for all that.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
