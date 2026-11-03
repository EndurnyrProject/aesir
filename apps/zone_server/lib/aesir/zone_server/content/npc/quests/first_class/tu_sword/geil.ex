defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuSword.Geil do
  @moduledoc """
  Geil, one of the four murder suspects in Morocc questioned during the Swordman training quest.

  ## Behavior

  - While the player is interrogating the suspects, protests his innocence and recites his
    piece of the secret code; the first time this also marks the interrogations as done.
  - Otherwise only preaches about living in harmony.

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
    spawn: [%{map: "morocc_in", x: 51, y: 101, dir: 3, sprite: 89, name: "Geil", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Geil]")

    case get_char_var(ctx, :tu_swordman, 0) do
      15 ->
        ctx |> recite_code() |> close()

      14 ->
        ctx |> recite_code() |> set_char_var(:tu_swordman, 15) |> close()

      _ ->
        ctx
        |> mes("We should all")
        |> mes("strive to live in")
        |> mes("peace and harmony")
        |> mes("with our fellow man.")
        |> next()
        |> mes("[Geil]")
        |> mes(
          "But fear, distrust and panic always seem to get in the way and mess up world events. We've got to find it within ourselves to get along with others. Don't you agree?"
        )
        |> close()
    end
  end

  defp recite_code(ctx) do
    ctx
    |> mes(
      "Were you sent by the authorities? Quit giving me such a hard time! I'm not the murderer! I don't even know who was killed. I'm not the one you're looking for!"
    )
    |> next()
    |> mes("[Geil]")
    |> mes("Sure, some weird")
    |> mes("guy told me some")
    |> mes(
      "kind of code related to all this, but that's it! That's all I know! I'm not the killer, I'm not an accessory, nothing!"
    )
    |> next()
    |> mes("[Geil]")
    |> mes("^5D478BTheisWesomeof^000000")
    |> mes("That's the code. I can't believe that I'm unable to forget this.")
    |> mes("I mean, I think I was drunk")
    |> mes("when that guy told me.")
    |> next()
    |> mes("[Geil]")
    |> mes(
      "What's so important about this code, and why do you guys keep hounding me about the murder?!"
    )
  end
end
