defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.TarshaCherno do
  @moduledoc """
  Follows Tarsha Cherno through the airship ticket quest.

  ## Behavior

  - Advances the search for Tarsha’s father and responds to the player’s progress.
  - Identifies her by a burn mark, while wrong choices cause damage.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 125,
        y: 99,
        dir: 3,
        sprite: 850,
        name: "Tarsha Cherno",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCherno

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :kain_ticket, 0) do
      12 -> identify_father(ctx)
      progress -> ctx |> dialogue(progress) |> close()
    end
  end

  defp dialogue(ctx, 7) do
    {ctx, _} = FCherno.call(ctx, [])
    set_char_var(ctx, :kain_ticket, 8)
  end

  defp dialogue(ctx, 8), do: inventions(ctx)
  defp dialogue(ctx, 9), do: family_history(ctx)
  defp dialogue(ctx, progress) when progress in [10, 11], do: awaiting_news(ctx)
  defp dialogue(ctx, progress) when progress > 12, do: gratitude(ctx)
  defp dialogue(ctx, _progress), do: busy(ctx)

  defp inventions(ctx) do
    ctx
    |> mes("[Tarsha Cherno]")
    |> mes("Although most of these")
    |> mes("contraptions aren't worth")
    |> mes("showing off, we've put a lot")
    |> mes("of work in inventing these")
    |> mes("machines. So, of course,")
    |> mes("they give us pride~")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("Maybe all these little")
    |> mes("projects might not be")
    |> mes("that impressive, but I like")
    |> mes("to think of them as stepping")
    |> mes("stones to future achievements.")
  end

  defp family_history(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me, ma'am,")
      |> mes("but you have a scar")
      |> mes("on your shoulder. Is")
      |> mes("that from an accident?")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("Oh, that's an old")
      |> mes("injury that happened")
      |> mes("years ago. I suppose")
      |> mes("I was quite the trouble")
      |> mes("maker to the people")
      |> mes("who raised me...")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("You see, I lost my parents")
      |> mes("when I was very young. It")
      |> mes("was only later when I realized")
      |> mes("I was raised by foster parents.")
      |> mes("I learned that my real mother")
      |> mes("died a long time ago...")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("As for my father, no")
      |> mes("one knows if he's dead")
      |> mes("or alive. I tried my best")
      |> mes("to my foster parents happy,")
      |> mes("but I ended up being too rebellious and giving them grief.")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("I finally left home and")
      |> mes("studied mechanics. I met")
      |> mes("my husband in school and")
      |> mes("it was the greatest thing that")
      |> mes("ever happened to me~")

    ctx = ctx |> emotion(:throb, getnpcid(ctx, "Theo Cherno")) |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("By the way, I heard")
      |> mes("your daughter singing")
      |> mes("some sort of Miner's Song.")
      |> mes("Did you teach her that?")
      |> emotion(:huk)

    ctx =
      ctx
      |> emotion(:huk, getnpcid(ctx, "Theo Cherno"))
      |> next()
      |> mes("[Theo Cherno]")
      |> mes("I don't understand")
      |> mes("why little Elle likes")
      |> mes("such a rowdy, man song.")
      |> mes("This is all your fault, Tarsha!")

    ctx =
      ctx
      |> emotion(:anger, getnpcid(ctx, "Theo Cherno"))
      |> next()
      |> emotion(:smile)
      |> mes("[Tarsha Cherno]")
      |> mes("Oh~hohohoho~")
      |> mes("I was too young to")
      |> mes("remember it clearly,")
      |> mes("but I'm sure my real")
      |> mes("father loved that song.")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("I barely recall that")
      |> mes("he used to sing it while")
      |> mes("cleaning our old house.")
      |> mes("Yes, I don't remember what")
      |> mes("he looked like, but he must")
      |> mes("have been a miner at one time.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("A miner...?")
      |> mes("(Wait, that crewman,")
      |> mes("Kain Himere! He was")
      |> mes("a miner who lost his")
      |> mes("daughter! Just maybe...)")
      |> next()
      |> emotion(:surprise)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("...!")
      |> mes("Tarsha...")
      |> mes("Your father")
      |> mes("may still be alive!")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("...What?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I've got to go check")
    |> mes("something now, but")
    |> mes("hopefully I'll be back")
    |> mes("soon with good news!")
    |> changequest(2080, 2081)
    |> set_char_var(:kain_ticket, 10)
  end

  defp awaiting_news(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Tarsha, I know someone")
    |> mes("who might be your father!")
    |> mes("Just wait for me and hopefully")
    |> mes("I'll bring back good news soon!")
  end

  defp gratitude(ctx) do
    ctx
    |> mes("[Tarsha Cherno]")
    |> mes("I've been feeling great")
    |> mes("after all you've done for")
    |> mes("us. Once again, I'd like to")
    |> mes("thank you, kind adventurer.")
  end

  defp busy(ctx) do
    ctx
    |> mes("[Tarsha Cherno]")
    |> mes("I'm sorry, but")
    |> mes("we're pretty busy.")
    |> mes("Please excuse us~")
  end

  defp identify_father(ctx) do
    ctx =
      ctx
      |> mes("[Tarsha Cherno]")
      |> mes("Oh, welcome back~")
      |> mes("So were you able to")
      |> mes("bring back good news?")
      |> emotion(:smile)
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Why, yes.")
      |> mes("Speaking of which,")
      |> mes("allow me to... check")
      |> mes("something first...")
      |> next()
      |> select([
        "Check her neck.",
        "Check her hands.",
        "Check her legs.",
        "Check her forehead."
      ])

    case choice do
      1 -> mistaken_choice(ctx, -10)
      2 -> found_father(ctx)
      3 -> mistaken_choice(ctx, -20)
      4 -> mistaken_choice(ctx, -10)
      _ -> ctx
    end
  end

  defp mistaken_choice(ctx, damage) do
    ctx
    |> mes("^3355FFUh oh...")
    |> mes("Nothing's there!^000000")
    |> next()
    |> mes("[Theo Cherno]")
    |> mes("H-how rude!")
    |> mes("Touching another")
    |> mes("man's wife...?!")
    |> next()
    |> specialeffect2(:pierce)
    |> percent_heal(hp: damage, sp: 0)
    |> close()
  end

  defp found_father(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou found")
      |> mes("a burn mark on")
      |> mes("her hand.^000000")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("That's it!")
      |> mes("Tarsha, your")
      |> mes("father's name is")
      |> mes("Kain Himere and he's")
      |> mes("working on the Airship")
      |> mes("as one of the crewmen.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("He misses you")
    |> mes("a lot and hopes")
    |> mes("that you can forgive")
    |> mes("him... Someday.")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("Are...")
    |> mes("Are you serious?")
    |> mes("My father's alive!")
    |> mes("Oh thank god! Thank")
    |> mes("you so much, adventurer!")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("...........")
    |> mes("So that means, my")
    |> mes("real name would be")
    |> mes("^3131FFTarsha Himere Cherno^000000.")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("Oh, you're a godsend!")
    |> mes("I'll never forget what you've")
    |> mes("done for me! I must repay")
    |> mes("you somehow! But all I know")
    |> mes("is mechanical engineering...")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("Oh, I know~")
    |> mes("If you have any")
    |> mes("^3131FFbroken equipment^000000,")
    |> mes("I can fix it with this")
    |> mes("Expert Repairman. It's")
    |> mes("one of our best inventions!")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("I must go and see")
    |> mes("my real father soon!")
    |> mes("I've missed him for years!")
    |> mes("Thank you again for all")
    |> mes("you've done for my family~")
    |> next()
    |> mes("[Tarsha Cherno]")
    |> mes("Oh, and before you")
    |> mes("go, would you go see")
    |> mes("Elle again? She wanted to")
    |> mes("talk to you for some reason.")
    |> changequest(2083, 2084)
    |> set_char_var(:kain_ticket, 13)
    |> close()
  end
end
