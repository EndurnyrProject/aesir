defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.SuspiciousMan do
  @moduledoc """
  A hired attacker waiting near the ice cave.

  ## Behavior

  - Attacks the player and reveals who hired him during the search for Phobe.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_fild01",
        x: 245,
        y: 325,
        dir: 3,
        sprite: 934,
        name: "Suspicious Man",
        scope: :shared,
        unique_name: "Suspicious Man#ra_in01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 6 or get_char_var(ctx, :lost_boy, 0) > 7 -> idle(ctx)
      get_char_var(ctx, :lost_boy, 0) == 6 -> confrontation(ctx)
      get_char_var(ctx, :lost_boy, 0) == 7 -> reminder(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp idle(ctx) do
    ctx
    |> mes("[Suspicious Man]")
    |> mes("Th-there's not enough")
    |> mes("air here, it's so stuffy!")
    |> mes("Hey, get away! You're")
    |> mes("wasting all of my")
    |> mes("precious oxygen!")
    |> close()
  end

  defp confrontation(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me, but do you")
      |> mes("know a man named")
      |> mes("Rogan? I'm here to--")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("Hah! I had no idea")
      |> mes("it'd be this simple!")
      |> mes("Easiest money I've")
      |> mes("ever made! Bwahahaha!")
      |> mes("Time for you to die, kid!")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("Hyah!")
      |> percent_heal(hp: -50, sp: 0)
      |> next()
      |> mes("^3355FFThis suspicious man")
      |> mes("wounded you with a throwing")
      |> mes("dagger, and then threw another")
      |> mes("one that you managed to dodge.")
      |> mes("You quickly retaliate to keep")
      |> mes("him from further harming you.^000000")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("Argh! I...")
      |> mes("I guess I underestimated")
      |> mes("you! You're a lot stronger")
      |> mes("than when you're taken by")
      |> mes("surprise, adventurer!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, who the hell are")
      |> mes("you?! Are you Rogan?")
      |> mes("Are you the one that")
      |> mes("kidnapped Phobe?")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("What th--? I didn't")
      |> mes("kidnap nobody! I don't")
      |> mes("know any Phobe! I was")
      |> mes("just hired to kill you and")
      |> mes("bring your body to my client.")
      |> mes("This wasn't what I expected.")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("Vincent's instructions")
      |> mes("were to kill anyone that")
      |> mes("asked about Rogan, some")
      |> mes("name he made up. My name")
      |> mes("is Mogan. Gosh... I thought")
      |> mes("you were a really bad guy.")
      |> next()
      |> mes("[Mogan]")
      |> mes("Hey, set me straight")
      |> mes("here. Did you steal")
      |> mes("something really")
      |> mes("valuable, like some")
      |> mes("red jewel or something?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Huh? No! Vincent actually")
      |> mes("sent me to look for the guy")
      |> mes("that stole that jewel, and")
      |> mes("to retrieve it for him!")
      |> next()
      |> mes("[Mogan]")
      |> mes("It looks like he set")
      |> mes("us up, dude. That's...")
      |> mes("That's really low. Sorry,")
      |> mes("if I had known, I wouldn't")
      |> mes("have done it. Why would")
      |> mes("he manipulate us like that?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I don't know...")
    |> mes("I'm going to talk")
    |> mes("to Vincent and make")
    |> mes("him explain everything.")
    |> set_char_var(:lost_boy, 7)
    |> changequest(8093, 8094)
    |> close()
  end

  defp reminder(ctx) do
    ctx =
      ctx
      |> mes("[Mogan]")
      |> mes("It looks like he set")
      |> mes("us up, dude. That's...")
      |> mes("That's really low. Sorry,")
      |> mes("if I had known, I wouldn't")
      |> mes("have done it. Why would")
      |> mes("he manipulate us like that?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I don't know...")
    |> mes("I'm going to talk")
    |> mes("to Vincent and make")
    |> mes("him explain everything.")
    |> close()
  end
end
