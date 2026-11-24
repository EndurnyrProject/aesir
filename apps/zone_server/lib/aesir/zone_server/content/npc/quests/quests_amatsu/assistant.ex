defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Assistant do
  @moduledoc """
  Manages the Momotaro field trip waiting room.

  ## Behavior

  - Explains the rules and returns or readmits participants according to their progress.
  - Starts and resets the arena waiting room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 52,
        y: 44,
        dir: 3,
        sprite: 109,
        name: "Assistant",
        scope: :shared,
        unique_name: "Assistant#ama"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ctx
    |> waitingroom("Waiting Exhibit.", 10, "Assistant#ama::OnStartArena", 1)
    |> enablewaitingroomevent("Assistant#ama")
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> disablenpc("Coach#ama")
    |> donpcevent("Am Mut#ama::OnReset")
    |> donpcevent("Dokebi#ez::OnReset")
    |> donpcevent("Dokebi#hd::OnReset")
    |> enablenpc("Grandma#ama1")
    |> enablenpc("Grandpa#ama")
    |> warpwaitingpc("ama_test", 50, 83)
    |> donpcevent("Timer#ama::OnEnable")
    |> disablewaitingroomevent("Assistant#ama")
  end

  def on_event("OnReset", ctx), do: enablewaitingroomevent(ctx, "Assistant#ama")

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :event_momo, 0) do
      0 -> explain(ctx)
      1 -> retry(ctx)
      2 -> success(ctx)
      _ -> weak_finish(ctx)
    end
  end

  defp explain(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Satoshi]")
      |> mes("Welcome to <Momotaro Field Trip>")
      |> mes(" ")
      |> next()
      |> mes("[Satoshi]")
      |> mes("I'm Satoshi who is in charge of the waiting room in <Momotaro Field Trip>.")
      |> next()
      |> mes("[Satoshi]")
      |> mes(
        "Originally, I was working for the publishing company, but we lacked workers for the Field Trip..."
      )
      |> mes("But working here is much better!")
      |> mes("Now I just watch people trying to accomplish the mission. Heh hehe~")
      |> next()
      |> mes("[Satoshi]")
      |> mes("................")
      |> mes("Just kidding")
      |> mes("*Wipes away sweat*")
      |> next()
      |> mes("[Satoshi]")
      |> mes("Well, let me explain")
      |> mes("about the rules in the Field Trip.")
      |> mes(" ")
      |> next()
      |> mes("[Satoshi]")
      |> mes("First of all...Did you hear")
      |> mes("about the story from the publisher?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      ctx
      |> mes("[Satoshi]")
      |> mes("Hehe...Good.")
      |> mes("Momotaro Story is our")
      |> mes("pride. It's the best story EVER.")
      |> mes("Hahahah!!!")
      |> next()
      |> mes("[Satoshi]")
      |> mes("...Hmmhmm.")
      |> next()
      |> mes("[Satoshi]")
      |> mes("The Field Trip is simple.")
      |> mes("Go inside and eliminate")
      |> mes("Dokebis bravely!!!")
      |> mes("Just like Momotaro!!!")
      |> mes("Understand? Bravely!!!")
      |> next()
      |> mes("[Satoshi]")
      |> mes("In addition, there are three")
      |> mes("things you need to know.")
      |> next()
      |> mes("[Satoshi]")
      |> mes("First....")
      |> mes("You can't come back once you clear the field trip. Keep that in mind.")
      |> next()
      |> mes("[Satoshi]")
      |> mes("Secondly....")
      |> mes("Q-pet is prohibited")
      |> mes("inside of the field trip.")
      |> mes("If you are with a pet,")
      |> mes("please change it to egg status.")
      |> next()
      |> mes("[Satoshi]")
      |> mes("And finally...")
      |> mes("One person can be on the")
      |> mes("field trip for 6 minutes.")
      |> next()
      |> mes("[Satoshi]")
      |> mes("Well then, please")
      |> mes("wait your turn")
      |> mes("in the waiting room.")
      |> mes("Good luck in fighting!!")
      |> close()
    else
      ctx
      |> mes("[Assistant]")
      |> mes("Eh? You can't just")
      |> mes("skip the story")
      |> mes("when you enter field trip!!")
      |> mes("I can't allow you to do that")
      |> mes("as Momotaro's fan!!!")
      |> next()
      |> mes("[Assistant]")
      |> mes("Please listen to the story")
      |> mes("from the publisher.")
      |> mes("Thank you.")
      |> mes("Bye~~")
      |> next()
      |> warp("amatsu", 223, 230)
    end
  end

  defp retry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Satoshi]")
      |> mes("Oh my...Are you alright?")
      |> mes("I thought it was entertaining but maybe it was too hard for you?")
      |> next()
      |> mes("[Satoshi]")
      |> mes("Now what are you going to do?")
      |> mes("Do you want to go in again?")
      |> next()
      |> select(["Yes", "No, I want to go back"])

    if choice == 1 do
      ctx
      |> mes("[Satoshi]")
      |> mes("The more effort you put into this, the sweeter victory will taste.")
      |> mes("Good luck in fighting!")
      |> close()
    else
      ctx
      |> mes("[Satoshi]")
      |> mes(
        "Well, I guess the reality of the situation is that you just can't fulfill the role of Momotaro..."
      )
      |> mes("Still, don't be depressed.")
      |> next()
      |> mes("[Satoshi]")
      |> mes("I think you've gained enough experience from the field trip.")
      |> next()
      |> mes("[Assistant]")
      |> mes("If you hear a good story,")
      |> mes("Please, contact our")
      |> mes("publishing company.")
      |> mes("Bye-")
      |> close()
      |> percent_heal(hp: 100, sp: 0)
      |> set_char_var(:event_momo, 0)
      |> warp("amatsu", 223, 230)
    end
  end

  defp success(ctx) do
    ctx
    |> mes("[Satoshi]")
    |> mes("Woohoo~ Congratulations!!")
    |> mes("You were so great!")
    |> next()
    |> mes("[Satoshi]")
    |> mes("It is time to say good bye.")
    |> mes("If you hear a good story,")
    |> mes("Please, contact our")
    |> mes("publishing company.")
    |> mes("Bye-")
    |> close()
    |> percent_heal(hp: 100, sp: 0)
    |> warp("amatsu", 223, 230)
  end

  defp weak_finish(ctx) do
    ctx
    |> mes("[Satoshi]")
    |> mes("Woohoo~ Congratulations!!")
    |> mes("You were so great!!")
    |> mes("Even though your finish was kind of weak...")
    |> next()
    |> mes("[Satoshi]")
    |> mes("It is time to say good bye.")
    |> mes("If you hear a good story,")
    |> mes("Please, contact our")
    |> mes("publishing company.")
    |> mes("Bye-")
    |> close()
    |> warp("amatsu", 223, 230)
  end
end
