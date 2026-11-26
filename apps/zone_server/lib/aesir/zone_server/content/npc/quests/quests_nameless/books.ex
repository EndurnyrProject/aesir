defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Books do
  @moduledoc """
  A collection of old books hides a bloodstained book needed for the quest.

  ## Behavior

  - Checks the player's carrying capacity before allowing the books to be examined.
  - Gives and opens the bloodstained book at the appropriate quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
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
        map: "abbey02",
        x: 224,
        y: 70,
        dir: 0,
        sprite: 111,
        name: "Books",
        scope: :shared,
        unique_name: "Books#Mona1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7766, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_monas, 0) < 21 ->
        ctx |> mes("^3355FFIt's just a bunch") |> mes("of old, moldy books.^000000") |> close()

      get_char_var(ctx, :aru_monas, 0) == 21 ->
        {ctx, choice} =
          ctx
          |> mes("^3355FFThere's a book stained")
          |> mes("with blood amongst all")
          |> mes("these old, moldy books.^000000")
          |> next()
          |> select(["Examine Book", "Ignore"])

        if choice == 1 do
          ctx
          |> set_char_var(:aru_monas, 22)
          |> give_item(7755, 1)
          |> readbook(7755, 1)
          |> close()
        else
          ctx
          |> mes("^3355FFThat book was probably")
          |> mes("worthless to you anyway.^000000")
          |> close()
        end

      true ->
        ctx
        |> mes("^3355FFThere are old books")
        |> mes("scattered all over here.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
