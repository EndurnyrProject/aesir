defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuSword.Hans do
  @moduledoc """
  Hans, one of the four murder suspects in Morocc questioned during the Swordman training quest.

  ## Behavior

  - While the player is interrogating the suspects, recites his piece of the secret code;
    the first time this also marks the interrogations as done.
  - Otherwise only says he has problems of his own.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "morocc", x: 240, y: 72, dir: 3, sprite: 86, name: "Hans", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Hans]")

    case get_char_var(ctx, :tu_swordman, 0) do
      15 ->
        ctx |> recite_code() |> close()

      14 ->
        ctx |> recite_code() |> set_char_var(:tu_swordman, 15) |> close()

      _ ->
        ctx
        |> mes("I'm sorry...")
        |> mes(
          "But I don't think I can be of any help to you. Right now, it seems that I've got problems of my own..."
        )
        |> close()
    end
  end

  defp recite_code(ctx) do
    ctx
    |> mes("Help me!")
    |> mes("Please help me!")
    |> mes("I'm no murderer!")
    |> mes("I'm practically")
    |> mes("harmless!")
    |> next()
    |> mes("[Hans]")
    |> mes("^5D478Bvictkleyundncem^000000")
    |> mes("This is code I know.")
    |> mes("Some strange person")
    |> mes("told it to me earlier and said")
    |> mes("that I'd need to know it soon!")
    |> next()
    |> mes("[Hans]")
    |> mes("He said that this code")
    |> mes("would save my life. First,")
    |> mes("I thought he was crazy, but for")
    |> mes("some reason I can't forget it.")
    |> next()
    |> mes("[Hans]")
    |> mes(
      "It's like he used magic or something to make it stick out in my brain. Please leave me alone, this is all I know!"
    )
  end
end
