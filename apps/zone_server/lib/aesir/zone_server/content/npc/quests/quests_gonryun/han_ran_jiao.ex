defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.HanRanJiao do
  @moduledoc """
  Han Ran Jiao seeks her lost family knife.

  ## Behavior

  - Starts the Lost Knife quest for adventurers at least level 20.
  - Accepts the recovered knife and rewards its return with two Blue Potions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 237,
        y: 226,
        dir: 3,
        sprite: 776,
        name: "Han Ran Jiao",
        scope: :shared,
        unique_name: "Han Ran Jiao#gon"
      }
    ]

  @knife 1201
  @blue_potion 505

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :nakha, 0) do
      0 ->
        start_quest(ctx)

      1 ->
        lost_knife(ctx)

      2 ->
        if count_item(ctx, @knife) > 0, do: return_knife(ctx), else: lost_knife(ctx)

      3 ->
        ctx
        |> mes("[Han Ran Jiao]")
        |> mes("My neighbor seemed looked pretty bothered about something...")
        |> mes("Oh well, I have better things to worry about than his fancy tea.")
        |> close()

      _ ->
        ctx
    end
  end

  defp start_quest(ctx) do
    ctx =
      ctx
      |> mes("[Han Ran Jiao]")
      |> mes("Oh no! What will I do?!")
      |> mes("I can't believe I dropped")
      |> mes("my irreplaceable knife! Ahhhhhh!")
      |> next()

    if base_level(ctx) >= 20 do
      ctx
      |> set_char_var(:nakha, 1)
      |> setquest(10034)
      |> afraid_of_monsters()
    else
      ctx
    end
  end

  defp lost_knife(ctx) do
    ctx
    |> mes("[Han Ran Jiao]")
    |> mes("Oh no! What will I do?")
    |> mes("I can't believe I dropped")
    |> mes("my irreplaceable knife! Ahhhhhh!")
    |> next()
    |> afraid_of_monsters()
  end

  defp afraid_of_monsters(ctx) do
    ctx
    |> mes("[Han Ran Jiao]")
    |> mes("I need to go down to get it")
    |> mes("but...the monsters...")
    |> mes("I'm so scared... What should I do?!")
    |> close()
  end

  defp return_knife(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Han Ran Jiao]")
      |> mes("Ehhhh... what should I do...")
      |> mes("Oh~! I didn't notice you there.")
      |> mes("Can I help you with anything?")
      |> mes("Hmm?")
      |> next()
      |> mes("[Han Ran Jiao]")
      |> mes("That...that knife!")
      |> mes("That's my ancestor's sacred knife")
      |> mes("that I accidentally dropped from")
      |> mes("here! Where did you get it!?")
      |> next()
      |> mes("[Han Ran Jiao]")
      |> mes("I dropped that knife from being")
      |> mes("careless. It belongs to one of my")
      |> mes("ancestors. I know it looks like")
      |> mes("a cheap knife...")
      |> next()
      |> mes("[Han Ran Jiao]")
      |> mes("But it has been in the")
      |> mes("family for a very long time.")
      |> mes("Would you please return that")
      |> mes("knife to me?")
      |> next()
      |> select(["Return the knife.", "Refuse."])

    if choice == 1 do
      ctx
      |> set_char_var(:nakha, 3)
      |> completequest(10035)
      |> delitem(@knife, 1)
      |> mes("[Han Ran Jiao]")
      |> mes("Thank you! Thank you so much!")
      |> mes("Please take these potions.")
      |> mes("They may not be much, but they")
      |> mes("are the best I can give you.")
      |> give_item(@blue_potion, 2)
      |> next()
      |> mes("[Han Ran Jiao]")
      |> mes("You kept my family heirloom safe!")
      |> mes("I give you my deepest gratitude")
      |> mes("for returning this.")
      |> close()
    else
      ctx
      |> mes("[Han Ran Jiao]")
      |> mes("No~! My family heirloom!!")
      |> mes("You scoundrel! May the spirits")
      |> mes("forever haunt you! My curse shall be upon your head!")
      |> close()
    end
  end
end
