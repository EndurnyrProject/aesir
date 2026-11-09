defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.OfficerA do
  @moduledoc """
  Officer A of the three-kingdom meeting, who plots with Officer B against Sikaiz's peaceful
  course.

  ## Behavior

  - At `ep13_ryu` step 18 shares the officers' scheme against Sikaiz, advances quest 10074 to
    10075 and sets the step to 19.
  - At step 19 takes the player's departure report, advancing quest 10075 to 10076 and the step
    to 20.
  - At step 20 sends the player back to the meeting room, and otherwise complains that the
    kingdoms' own interests come first.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "lhz_in01", x: 32, y: 22, dir: 3, sprite: 109, name: "Officer A", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      20 -> sent_back(ctx)
      19 -> report_accepted(ctx)
      18 -> scheming(ctx)
      _step -> own_interest(ctx)
    end
  end

  defp sent_back(ctx) do
    ctx
    |> mes("[Officer]")
    |> mes("Why don't you go back there?")
    |> mes("Are you afraid to go back?")
    |> mes("Khkhkh!")
    |> next()
    |> mes("[Officer]")
    |> mes("Just go back to the meeting room.")
    |> mes("Your allies are there together.")
    |> mes("Khkhkh!")
    |> mes("Nevermind.")
    |> mes("Bye.")
    |> close()
  end

  defp report_accepted(ctx) do
    ctx
    |> mes("[Officer A]")
    |> mes("So why do you come to me?")
    |> mes("What's wrong?")
    |> next()
    |> mes("[Officer B]")
    |> mes("Got any business?")
    |> next()
    |> mes("[Officer A]")
    |> mes("I think not.")
    |> mes("You come to tell me that you're leaving for the mission.")
    |> mes("Am I right?")
    |> next()
    |> mes("[Officer B]")
    |> mes("You were sent by Sikaiz...")
    |> mes("Right?")
    |> next()
    |> mes("[Officer A]")
    |> mes("Ok, I got your report.")
    |> mes("Just go back there.")
    |> mes("Good luck.")
    |> next()
    |> mes("[Officer B]")
    |> mes("Just do your best")
    |> mes("...or whatever you do...")
    |> next()
    |> changequest(10075, 10076)
    |> set_char_var(:ep13_ryu, 20)
    |> mes("[Officer A]")
    |> mes("Just return there. Good job.")
    |> close()
  end

  defp scheming(ctx) do
    ctx
    |> mes("[Officer A]")
    |> mes("Sikaiz isn't understandable...")
    |> mes("I can't help it...")
    |> next()
    |> mes("[Officer B]")
    |> mes("His voice for peace is")
    |> mes("only his own way.")
    |> mes("Three kingdoms for one mission...")
    |> mes("No peace...")
    |> mes("We even get no advantage.")
    |> next()
    |> mes("[Officer A]")
    |> mes(
      "We can't leave them as they are now. Though I am the leader among them, I'm just a figurehead."
    )
    |> next()
    |> mes("[Officer A]")
    |> mes("Is there any way to change their ways?")
    |> next()
    |> mes("[Officer B]")
    |> mes("If they changed,")
    |> mes("we wouldn't get in trouble.")
    |> mes("But he is not compromising.")
    |> next()
    |> mes("[Officer A]")
    |> mes("So what??")
    |> mes("We wouldn't get our interests,")
    |> mes("and just do nothing for ourselves?")
    |> next()
    |> mes("[Officer B]")
    |> mes("There's always Munkenro.")
    |> next()
    |> mes("[Officer A]")
    |> mes("So what...?")
    |> next()
    |> mes("[Officer B]")
    |> mes("As honest as Sikaiz...")
    |> mes("As flexible as Sikaiz...")
    |> mes("But easy to go over him...")
    |> next()
    |> mes("[Officer B]")
    |> mes("We can't cut him out,")
    |> mes("so just take the lead from Munkenro. It's easier!")
    |> next()
    |> mes("[Officer A]")
    |> mes("Oh!!")
    |> mes("That's a good idea.")
    |> mes("Anyway...")
    |> mes("Some visitors are coming.")
    |> mes("Let's talk about it later.")
    |> next()
    |> changequest(10074, 10075)
    |> set_char_var(:ep13_ryu, 19)
    |> mes("[Officer B]")
    |> mes("Um, what's your business?")
    |> close()
  end

  defp own_interest(ctx) do
    ctx
    |> mes("[Officer A]")
    |> mes("For our own interest,")
    |> mes("we need to abandon other kingdoms.")
    |> close()
  end
end
