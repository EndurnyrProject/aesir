defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Lord do
  @moduledoc """
  Lord Bai Long welcomes visitors and resolves the Poison King quest.

  ## Behavior

  - He expels suspicious players and rewards the delivery of the journal.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in01",
        x: 99,
        y: 158,
        dir: 4,
        sprite: 821,
        name: "Lord",
        scope: :shared,
        unique_name: "Lord#bailong"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FF * Wait a minute! *")
        |> mes(
          "Right now you're carrying too many items. Please put some of your things into Kafra Storage and try again.^000000"
        )
        |> close()

      get_char_var(ctx, :ch_poison, 0) in [12, 16] ->
        ctx
        |> mes("[Lord Bai Long]")
        |> mes("Hey...!")
        |> mes("You're not doing")
        |> mes("anything suspicious")
        |> mes("are you?")
        |> next()
        |> mes("^3355FFYou run away")
        |> mes("from Bai Long as")
        |> mes("fast as you can!^000000")
        |> close2()
        |> warp("louyang", 218, 246)

      true ->
        welcome(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp welcome(ctx) do
    ctx =
      ctx
      |> mes("[Lord Bai Long]")
      |> mes("Hahahaha!")
      |> mes("Welcome to Luoyang!")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("Luoyang is such a great city.")
      |> mes("We've protected this land for forty years from the invasions of evil creatures!")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("I hope you enjoy")
      |> mes("your stay here,")
      |> mes("Midgardian!")
      |> next()

    if get_char_var(ctx, :ch_poison, 0) == 18 do
      ctx
      |> mes("^3355FFYou give Nagash Arses' Journal")
      |> mes("to Bai Long. He reads it intently, slowly turning each page.^000000")
      |> next()
      |> mes("^3355FFHe's completely silent for about fifteen minutes, and focuses all")
      |> mes("of his attention of the journal.^000000")
      |> next()
      |> mes("^3355FFA single tear trickles")
      |> mes("from his eye as he reads")
      |> mes("the words of Nagash Arse...^000000")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("Thank you..")
      |> mes("Adventurer...")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("Thank you so much.")
      |> mes("You've helped me make")
      |> mes("up with an old friend!")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("I, Bai Long, will work on giving")
      |> mes(
        "fair treatment to all of martial arts organizations, regardless of their methods or philosophies!"
      )
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("I will also forgive Song Zhi Du, even if he tried to poison me.")
      |> mes("He is innocent...")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes(
        "As a matter of fact, it was reported to me that Nagash was deported to his homeland after"
      )
      |> mes("that incident. I had no idea")
      |> mes("he was in jail!")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("Thank you so")
      |> mes("much for your help!")
      |> next()
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes(
        "Please, take this as a token of gratitute. And please deliver this letter to Nagash and Song Zhi Du for me."
      )
      |> set_char_var(:ch_poison, 19)
      |> changequest(11081, 11802)
      |> give_item(603, 1)
      |> next()
      |> mes("^3355FFYou obtained ^0000FFBai Long's letter^000000.")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes("Thank you in advance.")
      |> close()
    else
      ctx
      |> mes("[Lord Bai Long]")
      |> mes("How could I have lost my friend from our glory days? Hmm...?")
      |> mes("Oh, I didn't realize you were still there... Listening to me.")
      |> next()
      |> mes("[Lord Bai Long]")
      |> mes(
        "I'm sorry, I was just talking to myself. I hope you have a good time while staying here in Luoyang."
      )
      |> close()
    end
  end
end
