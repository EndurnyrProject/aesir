defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.LordOfPalace do
  @moduledoc """
  Asks visitors to help his ailing mother.

  ## Behavior

  - Starts the investigation and tracks its progress.
  - Exchanges proof of treatment for a Transit Permit.

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
        map: "ama_in02",
        x: 200,
        y: 176,
        dir: 4,
        sprite: 768,
        name: "Lord of Palace",
        scope: :shared,
        unique_name: "Lord of Palace#ama"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :event_amatsu, 0) do
      0 -> dismiss(ctx)
      1 -> introduction(ctx)
      5 -> treatment(ctx)
      6 -> welcome(ctx)
      _ -> waiting(ctx)
    end
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Ishida Yoshinaga]")
    |> mes("What! A foreigner...? *Phew*")
    |> mes("I'm sorry, but I'm not in")
    |> mes("the mood to meet new people!")
    |> next()
    |> mes("[Ishida Yoshinaga]")
    |> mes("Get out! I'm not interested")
    |> mes("in who you are.")
    |> mes("I'm not feeling well!")
    |> close()
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ishida Yoshinaga]")
      |> mes("What! A foreigner? What brings")
      |> mes("you here? If it is not urgent,")
      |> mes("come to me another time...!")
      |> next()
      |> select([
        "I heard about your mother...",
        "Your last name is nice",
        "Who are you?"
      ])

    case choice do
      1 -> request_help(ctx)
      2 -> compliment(ctx)
      3 -> identify(ctx)
      _ -> ctx
    end
  end

  defp request_help(ctx) do
    ctx =
      ctx
      |> mes("[Ishida Yoshinaga]")
      |> mes("Oh...So you know about her disease?")
      |> mes("I've heard that, in foreign lands,")
      |> mes("the body of medical knowledge can")
      |> mes("be quite amazing.")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Welcome. As you know, I'm the")
      |> mes("lord of Toukoujyo,")
      |> mes("Ishida Yoshinaga. Nice to")
      |> mes("meet you.")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Let's get to the point.")
      |> mes("My mother is not doing well recently. I know you are here because of that.")
      |> mes("Can you cure her disease?")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Until now, many famous doctors")
      |> mes("have visited her, but they")
      |> mes("all failed to cure her disease")
      |> mes("and made it worse...")
      |> mes("They disappointed me.")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("You, who hail from Midgard,")
      |> mes("may be able to cure my mother's disease. I will reward you well if you succeed...")
      |> next()
      |> set_char_var(:event_amatsu, 2)

    ctx =
      if isbegin_quest(ctx, 8131) == 1 do
        changequest(ctx, 8131, 8132)
      else
        setquest(ctx, 8132)
      end

    ctx
    |> mes("[Ishida Yoshinaga]")
    |> mes("I beg you...Please.")
    |> mes("My mother is living in a house outside of the palace.")
    |> mes("Come to me when you finish your treatment.")
    |> close()
  end

  defp compliment(ctx) do
    ctx
    |> mes("[Ishida Yoshinaga]")
    |> mes("Nice!? So What?!")
    |> mes("Read my name until you get")
    |> mes("tired of it! Darn it!")
    |> next()
    |> mes("[Ishida Yoshinaga]")
    |> mes("Joking, even in this critical situation... *Phew*...")
    |> mes("Please have a good time in Amatsu.")
    |> mes("...Whatever!")
    |> close()
  end

  defp identify(ctx) do
    ctx
    |> mes("[Ishida Yoshinaga]")
    |> mes("...me? Don't you know? Huh?")
    |> mes("I'm the lord of this palace.")
    |> mes("If you don't know, talk to")
    |> mes("the soldiers outside!")
    |> close()
  end

  defp treatment(ctx) do
    if count_item(ctx, 1022) > 0 do
      ctx
      |> mes("[Ishida Yoshinaga]")
      |> mes("I've heard the great news!")
      |> mes("My mother seems to have gotten better. What was her disease?")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("A fox? Is that so? Oh...")
      |> mes("It wasn't a disease...!!")
      |> mes("Why didn't I notice?!")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Darn fox. To run away and")
      |> mes("take revenge on me in such a")
      |> mes("way...Well, then. There's no chance of revenge now... Hahaha!")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Hmm, Mmm. Hmm...")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Anyway, thank you for helping me.")
      |> mes("Mother will be okay now...")
      |> mes("I want to reward you...")
      |> mes("But what would be nice...?")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Alright, I will give you")
      |> mes("a Transit Permit.")
      |> mes("You can go anywhere")
      |> mes("with this ticket.")
      |> next()
      |> set_char_var(:event_amatsu, 6)
      |> completequest(8135)
      |> delitem(1022, 1)
      |> give_item(7160, 1)
      |> mes("[Ishida Yoshinaga]")
      |> mes("This isn't a big reward but")
      |> mes("someday it will be useful for you.")
      |> mes("Ask my soldier, 'Jyuro' about the details.")
      |> close()
    else
      ctx
      |> mes("[Ishida Yoshinaga]")
      |> mes("Hmm, I heard that my mother")
      |> mes("got better...but")
      |> mes("How can I know if you cured")
      |> mes("her or not?")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Is there any evidence to prove")
      |> mes("that you cured her?")
      |> next()
      |> mes("[Ishida Yoshinaga]")
      |> mes("Show me the evidence to prove")
      |> mes("your treatment. I've been")
      |> mes("meeting so many foreigners.")
      |> mes("But not all of them are trustworthy.")
      |> mes("Well... Have a good time.")
      |> close()
    end
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Ishida Yoshinaga]")
    |> mes("*Chuckle* Have a good time")
    |> mes("in Amatsu.....")
    |> mes("Foreigners are always welcome.")
    |> close()
  end

  defp waiting(ctx) do
    ctx
    |> mes("[Ishida Yoshinaga]")
    |> mes("How is my mom's status?")
    |> mes("If you find the name of the disease, please tell me.")
    |> mes("I was worrying about")
    |> mes("her all night.")
    |> next()
    |> mes("[Ishida Yoshinaga]")
    |> mes("Because you carry with you")
    |> mes("knowledge from Midgard,")
    |> mes("I have faith in your ability.")
    |> close()
  end
end
