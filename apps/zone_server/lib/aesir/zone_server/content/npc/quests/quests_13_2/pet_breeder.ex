defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.PetBreeder do
  @moduledoc """
  Guides Pinedel’s pet research and handles a wanted criminal report.

  ## Behavior

  - Offers a recurring Draco egg collection quest and rewards completed deliveries.
  - Accepts completed runaway Dandelion reports.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 146,
        y: 306,
        dir: 3,
        sprite: 982,
        name: "Pet Breeder",
        scope: :shared,
        unique_name: "Pet Breeder#ep13_eden01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        ctx
        |> mes("Wait a moment!!")
        |> mes("You have too many items.")
        |> mes("You can't receive this.")
        |> mes("Lighten your weight and")
        |> mes("try again.")
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) < 6 ->
        ctx
        |> mes("[Pinedel]")
        |> mes("Why isn't it working, Taab?")
        |> mes("That should be working.")
        |> next()
        |> mes("[Taab]")
        |> mes("That's very dangerous. Do you want to die..?!")
        |> next()
        |> mes("[Pinedel]")
        |> mes("Are you ignoring cute pets??")
        |> mes("We've been able to get Pickys and even Zealotus!")
        |> next()
        |> mes("[Taab]")
        |> mes("No way, even if you ask me...")
        |> mes("Hillslion is very adorable...")
        |> mes("But you can't.")
        |> next()
        |> mes("[Pinedel]")
        |> mes("Then let me know why you object to this.")
        |> next()
        |> mes("[Taab]")
        |> mes("It's too dangerous. I've trained monsters before.")
        |> mes("Hillslions look cute and adorable, but it's not very realistic.")
        |> next()
        |> mes("[Taab]")
        |> mes("Can't you see that?")
        |> mes("I've tried to train them... but I couldn't.")
        |> mes("How can we can train them as a cute pet...?")
        |> next()
        |> mes("[Taab]")
        |> mes("It would definitely try to escape from us...")
        |> mes("Then he would become very awful.")
        |> mes("I don't agree with this.")
        |> next()
        |> mes("[Pinedel]")
        |> mes("Nah...")
        |> mes("Can't we control them with magical power?")
        |> mes("We've done it before......")
        |> next()
        |> mes("- They just continue to argue -")
        |> close()

      true ->
        discuss_research(ctx)
    end
  end

  defp discuss_research(ctx) do
    {ctx, topic} =
      ctx
      |> mes("[Pinedel]")
      |> mes("Ah, Taab isn't flexible at all.")
      |> mes("Hey there! What's up??")
      |> next()
      |> select(["Notice for criminal report", "Cute pet investigation."])

    if topic == 1,
      do: criminal_report(ctx, get_char_var(ctx, :ep13_2_wanted, 0)),
      else: egg_research(ctx, get_char_var(ctx, :ep13_2_dayegg, 0))
  end

  defp criminal_report(ctx, 1) do
    if checkquest(ctx, 7076, :hunting) == 2 do
      ctx
      |> mes("[Pinedel]")
      |> mes("Have you hunted the Runaway Dandelion?")
      |> mes("Ok, I accept you.")
      |> mes("Here's something Rin was storing here.")
      |> next()
      |> mes("[Pinedel]")
      |> mes("This is Rin's cherished treasure box...")
      |> mes("This is enough payment, right?")
      |> completequest(7076)
      |> set_char_var(:ep13_2_wanted, 2)
      |> give_item(7444, 1)
      |> close()
    else
      ctx
      |> mes("[Pinedel]")
      |> mes("I know you haven't terminated the Runaway Dandelion yet.")
      |> mes("Don't take me for a fool.")
      |> close()
    end
  end

  defp criminal_report(ctx, 2) do
    ctx
    |> mes("[Pinedel]")
    |> mes("I will forward everything to Rin.")
    |> mes("She'll love it.")
    |> mes("Just tell her your name #{char_name(ctx, 0)}.")
    |> next()
    |> mes("[Pinedel]")
    |> mes("I can remember that I've heard about you from Rin.")
    |> mes("But Rin likes you, so that must mean that you're nice.")
    |> close()
  end

  defp criminal_report(ctx, _wanted) do
    ctx
    |> mes("[Pinedel]")
    |> mes("Seaching for a criminal?")
    |> mes("I'm not sure that you're involved in it.")
    |> close()
  end

  defp egg_research(ctx, 1) do
    if count_item(ctx, 6093) > 9 do
      ctx
      |> mes("[Pinedel]")
      |> mes("Oh! Nice!")
      |> mes("I can go through this study deeper with your assistance.")
      |> next()
      |> mes("[Pinedel]")
      |> mes("I will try to make these Dragon eggs into cute pets.")
      |> mes("Don't expect much!")
      |> mes("Come back after a day to check on the progress.")
      |> delitem(6093, 10)
      |> erasequest(7077)
      |> setquest(7078)
      |> set_char_var(:ep13_2_dayegg, 2)
      |> getexp(40_000, 40_000)
      |> give_item(6081, 1)
      |> give_item(6080, 1)
      |> close()
    else
      ctx
      |> mes("[Pinedel]")
      |> mes(
        "Draco was being kept in the nest just before hatching. Please collect 10 Dragon eggs for me."
      )
      |> mes("You know, those are hard to hatch in captivity.")
      |> close()
    end
  end

  defp egg_research(ctx, 2) do
    ctx =
      ctx
      |> mes("[Pinedel]")
      |> mes("Those eggs are about to hatch now.")
      |> mes("I will investigate those back home.")

    if checkquest(ctx, 7078, :playtime) in [0, 1] do
      ctx
      |> mes("For now I still need more time.")
      |> next()
      |> mes("[Pinedel]")
      |> mes("Can you come back here tomorrow?")
      |> close()
    else
      ctx |> close() |> erasequest(7078) |> set_char_var(:ep13_2_dayegg, 3)
    end
  end

  defp egg_research(ctx, 3) do
    {ctx, choice} =
      ctx
      |> mes("[Pinedel]")
      |> mes("Do you want to help me gather more Dragon eggs today?")
      |> mes("I want to try many things with those eggs.")
      |> next()
      |> select(["Sure.", "Sorry, I can't."])

    if choice == 1 do
      ctx
      |> mes("[Pinedel]")
      |> mes("Please collect 10 Draco Eggs.")
      |> set_char_var(:ep13_2_dayegg, 1)
      |> setquest(7077)
      |> close()
    else
      ctx
      |> mes("[Pinedel]")
      |> mes("Ok. You have your own business here.")
      |> mes("Go ahead.")
      |> close()
    end
  end

  defp egg_research(ctx, _progress) do
    {ctx, choice} =
      ctx
      |> mes("[Pinedel]")
      |> mes("I am investigating cute pets.")
      |> mes("Ash-vacuum has several monsters that I think could become cute pets.")
      |> next()
      |> mes("[Pinedel]")
      |> mes("The objective is one Dragon egg!")
      |> mes("Can you bring me a Dragon Egg?")
      |> next()
      |> select(["Yes.", "Nope."])

    if choice == 1 do
      ctx
      |> mes("[Pinedel]")
      |> mes("There would be Dragon nest in the cave you found out.")
      |> mes("There should be nice Dragon Eggs.")
      |> next()
      |> mes("[Pinedel]")
      |> mes("Please collect 10 Draco Eggs.")
      |> mes("Let's work together to make them as pets.")
      |> set_char_var(:ep13_2_dayegg, 1)
      |> setquest(7077)
      |> close()
    else
      ctx
      |> mes("[Pinedel]")
      |> mes("I know it's not the easiest task.")
      |> mes("But I refuse to give up.")
      |> mes("I will make it into a cute pet someday.")
      |> next()
      |> mes("[Taab]")
      |> mes("Would you just give up making exogamous beings into cute pets...")
      |> mes(" ")
      |> mes("[Pinedel]")
      |> mes("Taab doesn't have any guts!")
      |> close()
    end
  end
end
