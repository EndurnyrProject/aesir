defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.LibraryPartTimer do
  @moduledoc """
  The library part-timer helps the player find books and old newspapers.

  ## Behavior

  - Dialogue changes with Crow of the Fate progress, including a vision that transports the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "yuno_in04",
        x: 111,
        y: 57,
        dir: 3,
        sprite: 862,
        name: "Library Part-Timer",
        scope: :shared,
        unique_name: "Library Part-Timer#garas"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :barmunt_crow, 0) do
      3 -> find_bestseller(ctx)
      7 -> find_newspapers(ctx)
      11 -> recall_story(ctx)
      12 -> recover_from_vision(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp find_bestseller(ctx) do
    ctx
    |> mes("[Library Part-Timer]")
    |> mes("People should learn to put away books after pulling them out.")
    |> mes("All these books piled up in the cart make me feel so frustrated, you know? Sigh...")
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("...Now how may I help you?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(
      "I'm looking for a book called <The Crow of the Fate> written by Oliver Hilpert... Ahchoo!"
    )
    |> emotion(:kek, playerattached(ctx))
    |> specialeffect2(:venomdust)
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("Ah, I remember that one... It's the one most frequently left in the cart.")
    |> mes(
      "Please enter the room on the ^3131FFright side^000000. You can find it in the Bestseller corner."
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Thanks.")
    |> close()
  end

  defp find_newspapers(ctx) do
    ctx
    |> mes("[Library Part-Timer]")
    |> mes("How may I help you?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Yes, umm... ahchoo! Where can I find old news articles...? Ahchoo!")
    |> specialeffect2(:venomdust)
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("Oh, you can find them in a corner of the right room.")
    |> mes("Please be careful when you handle them since most of them are pretty ancient.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Thanks... Ahchoo!")
    |> specialeffect2(:venomdust)
    |> close()
  end

  defp recall_story(ctx) do
    ctx
    |> mes("[Library Part-Timer]")
    |> mes("People should learn to put away books after pulling them out.")
    |> mes("All these books piled up in the cart make me feel so frustrated, you know? Sigh...")
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("...How may I help you?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(
      "Cough... I'm looking for a book called <The Crow of the Fate> written by Oliver Hilpert."
    )
    |> specialeffect2(:venomdust)
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("Ah, I remember that one... It's the one most frequently left in the cart.")
    |> mes("Go ^3131FFupstairs^000000, and check the left shelf.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Thanks.")
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("Oliver Hilpert has attained huge fame despite his young age.")
    |> mes(
      "I've read his <The Trace of the Fate> at least several times. I mean, that book is so captivating that I can never get tired of reading it."
    )
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("Umm... The most impressive scene was... Err...")
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes(
      "Right! When the hero was meeting his end in the burning mansion... ^FF0000-- BEEP --^000000"
    )
    |> specialeffect2(:bash3d2)
    |> close2()
    |> warp("que_ba", 264, 186)
  end

  defp recover_from_vision(ctx) do
    ctx
    |> mes("[Library Part-Timer]")
    |> mes("Excuse me, are you okay? I mean, you just kind of drifted off all of a sudden.")
    |> mes("You look a little pale.")
    |> next()
    |> mes("[Library Part-Timer]")
    |> mes("Why don't you go inside and take a rest? Read <The Trace of the Fate> or something.")
    |> mes("You can find the book at the left bookshelf upstairs.")
    |> close()
  end
end
