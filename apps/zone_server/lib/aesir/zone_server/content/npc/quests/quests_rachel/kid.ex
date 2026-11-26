defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Kid do
  @moduledoc """
  Phobe, a runaway boy involved in the missing jewel investigation.

  ## Behavior

  - Returns the jewel when confronted and asks the player to reassure his mother.

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
        map: "rachel",
        x: 263,
        y: 32,
        dir: 3,
        sprite: 931,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ra_in01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 7 -> dismissal(ctx)
      get_char_var(ctx, :lost_boy, 0) == 8 -> confront_phobe(ctx)
      get_char_var(ctx, :lost_boy, 0) == 9 -> reminder(ctx)
      true -> scold(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp dismissal(ctx) do
    ctx |> mes("[Kid]") |> mes("Leave me alone!") |> close()
  end

  defp confront_phobe(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou catch a shining")
      |> mes("glint from this boy's")
      |> mes("back pocket. Perhaps he")
      |> mes("has the jewel that Vincent")
      |> mes("wants you to retrieve.^000000")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, you.")
      |> mes("You must be")
      |> mes("Phobe, right?")
      |> next()
      |> mes("[Kid]")
      |> mes("Yeah?")
      |> mes("So what?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Your father sent")
      |> mes("me here to find you.")
      |> next()
      |> mes("[Phobe]")
      |> mes("No! Don't touch me!")
      |> mes("I have no father!")
      |> mes("H-he's dead to me!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, in any case, I need")
      |> mes("to return the jewel that")
      |> mes("you're hiding in your pocket.")
      |> mes("I know that it really belongs")
      |> mes("to Sir Zhed.  If I don't, then")
      |> mes("your father will be in trouble.")
      |> next()
      |> mes("[Phobe]")
      |> mes("Hah! You mean ''Mister")
      |> mes("Vincent!'' That's fine")
      |> mes("by me! That's exactly")
      |> mes("why I took this thing!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Oh, yeah? How do you")
      |> mes("think Ms. Jenny will")
      |> mes("feel? Do you think")
      |> mes("that she'll be happy")
      |> mes("hearing about this?")
      |> next()
      |> mes("[Phobe]")
      |> mes("..............................")
      |> mes("...So you know about")
      |> mes("our family secret, huh?")
      |> mes("Alright, I'll give this to")
      |> mes("you. But I'm doing this for")
      |> mes("my mom, and not for him!")
      |> next()
      |> mes("^3355FFPhobe gingerly pulls")
      |> mes("the shining red jewel")
      |> mes("from his pocket and")
      |> mes("reluctantly hands it to you.^000000")
      |> next()
      |> mes("[Phobe]")
      |> mes("Just so you know,")
      |> mes("I don't plan on going")
      |> mes("back home! Well, just")
      |> mes("not this second anyway.")
      |> mes("But let my mom know that")
      |> mes("I'm fine and not to worry.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Alright, I'll tell your mom")
    |> mes("But you should be getting")
    |> mes("back to them soon. Your")
    |> mes("father took a really big")
    |> mes("risk covering up for you.")
    |> next()
    |> mes("[Phobe]")
    |> mes("Hmpf! I...")
    |> mes("I don't care!")
    |> next()
    |> mes("^3355FFIt doesn't look like")
    |> mes("you can force Phobe to")
    |> mes("return home for now, so")
    |> mes("you should bring this red")
    |> mes("jewel back to Vincent.^000000")
    |> set_char_var(:lost_boy, 9)
    |> changequest(8095, 8096)
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Phobe]")
    |> mes("I... I'm not ready")
    |> mes("to go back home just")
    |> mes("fine, and let Mister Vincent")
    |> mes("know that I'm not sorry")
    |> mes("for what I did, okay?!")
    |> next()
    |> mes("^3355FFIt doesn't look like")
    |> mes("you can force Phobe to")
    |> mes("return home for now, so")
    |> mes("you should bring this red")
    |> mes("jewel back to Vincent.^000000")
    |> close()
  end

  defp scold(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You know, you should")
      |> mes("quit making trouble and")
      |> mes("listen to your parents.")
      |> next()
      |> mes("[Phobe]")
      |> mes("You're not the boss")
      |> mes("of me! Mind your own")
      |> mes("business! Jeez louise!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I can't mind my own")
    |> mes("business if your actions")
    |> mes("are causing this much trouble")
    |> mes("to so many other people! You")
    |> mes("need to act more responsibly!")
    |> next()
    |> mes("[Phobe]")
    |> mes("Mmmrrrr...")
    |> mes("Gosh... Fine.")
    |> close()
  end
end
