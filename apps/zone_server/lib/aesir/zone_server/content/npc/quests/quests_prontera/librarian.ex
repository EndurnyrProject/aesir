defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Librarian do
  @moduledoc """
  The librarian handles lost books and library etiquette.

  ## Behavior

  - Replaces a lost quest book for 700 zeny when the player reports it.
  - Otherwise describes her work or asks for silence.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 162,
        y: 99,
        dir: 4,
        sprite: 67,
        name: "Librarian",
        scope: :shared,
        unique_name: "Librarian#curse"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.")
        |> close()

      get_char_var(ctx, :prt_curse, 0) == 3 and count_item(ctx, 7431) < 1 ->
        report_lost_book(ctx)

      true ->
        ctx
        |> mes("[Librarian]")
        |> mes("Being a librarian can")
        |> mes("be pretty rough. People")
        |> mes("just leave the books all")
        |> mes("scattered, but expect them")
        |> mes("to be organized. Ooh, books")
        |> mes("are always getting lost too...")
        |> next()
        |> mes("[Librarian]")
        |> mes("When you have")
        |> mes("to clean up their")
        |> mes("messes, you get to")
        |> mes("realize how sloppy")
        |> mes("people can really be.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp report_lost_book(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Librarian]")
      |> mes("Please make sure to return")
      |> mes("library books to the correct")
      |> mes("place after you use them.")
      |> mes("We don't have enough staff")
      |> mes("to organize all these books...")
      |> next()
      |> select(["Report the loss of the books", "End Conversation"])

    if choice == 1 do
      replace_book(ctx)
    else
      ctx
      |> mes("[Librarian]")
      |> mes("Please keep silent")
      |> mes("while inside the library.")
      |> mes("Thank you for cooperating.")
      |> close()
    end
  end

  defp replace_book(ctx) do
    ctx =
      ctx
      |> mes("[Librarian]")
      |> mes("Oh, you lost some books?")
      |> mes("Please write down the book")
      |> mes("titles and pay the 700 zeny")
      |> mes("penalty charge. Aftewards,")
      |> mes("we will provide you with")
      |> mes("replacement copies.")
      |> next()

    if zeny(ctx) > 699 do
      ctx
      |> mes("[Librarian]")
      |> mes("Ah, here you are.")
      |> mes("Please take these")
      |> mes("replacement copies,")
      |> mes("and try not to lose")
      |> mes("them again. Thank you.")
      |> pay_zeny(700)
      |> give_item(7431, 1)
      |> close()
    else
      ctx
      |> mes("[Librarian]")
      |> mes("Hmm...")
      |> mes("Come back as soon")
      |> mes("as you can with the")
      |> mes("700 zeny to pay the")
      |> mes("lost book penalty charge.")
      |> close()
    end
  end
end
