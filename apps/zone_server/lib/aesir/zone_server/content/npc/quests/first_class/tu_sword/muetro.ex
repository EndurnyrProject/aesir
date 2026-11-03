defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuSword.Muetro do
  @moduledoc """
  Muetro, one of the four murder suspects in Morocc questioned during the Swordman training quest.

  ## Behavior

  - While the player is interrogating the suspects, grudgingly gives up his piece of the
    secret code; the first time this also marks the interrogations as done.
  - Otherwise only sighs about fate.

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
    spawn: [%{map: "morocc", x: 82, y: 292, dir: 5, sprite: 84, name: "Muetro", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Muetro]")

    case get_char_var(ctx, :tu_swordman, 0) do
      15 ->
        ctx |> recite_code() |> close()

      14 ->
        ctx |> recite_code() |> set_char_var(:tu_swordman, 15) |> close()

      _ ->
        ctx
        |> mes("^666666*Sigh*^000000")
        |> mes("I try and I try, but sometimes ridiculous things happen and")
        |> mes("I can't do anything about them.")
        |> next()
        |> mes("[Muetro]")
        |> mes("I suppose it's fate. There's no escaping what I can't possibly")
        |> mes("hope to control or understand.")
        |> close()
    end
  end

  defp recite_code(ctx) do
    ctx
    |> mes("You're just")
    |> mes("like all the others.")
    |> mes("You want the code")
    |> mes("I know, right?")
    |> next()
    |> mes("[Muetro]")
    |> mes("^5D478BConBanfoevidehi^000000")
    |> mes("Happy now? Now")
    |> mes("leave me alone and")
    |> mes("catch the murderer.")
  end
end
