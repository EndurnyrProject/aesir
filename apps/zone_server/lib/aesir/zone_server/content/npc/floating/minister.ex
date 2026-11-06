defmodule Aesir.ZoneServer.Content.Npc.Floating.Minister do
  @moduledoc """
  Palace Minister of the Archer training quest, who deflects every question about the royal
  family.

  ## Behavior

  - Greets the player and, depending on the quest step, either explains away the screams heard
    in the palace or coldly deflects further questions.
  - Advances the palace quest step from 5 to 6 after explaining the screams.
  - Speaks at length only for Acolytes who reached step 25 of their own training quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_cas",
        x: 97,
        y: 289,
        dir: 3,
        sprite: 55,
        name: "Minister",
        scope: :renewal,
        unique_name: "Minister#tu"
      },
      %{
        map: "prt_castle",
        x: 76,
        y: 165,
        dir: 6,
        sprite: 55,
        name: "Minister",
        scope: :pre_renewal,
        unique_name: "Minister#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Minister]")
    |> mes("The royal family")
    |> mes("is extremely busy")
    |> mes("at the moment, handling")
    |> mes("our nation's administration.")
    |> respond_to_inquiry()
    |> close()
  end

  defp respond_to_inquiry(ctx) do
    case get_char_var(ctx, :tu_archer02, 0) do
      5 -> explain_the_screams(ctx)
      7 -> cold_refusal(ctx)
      _ -> acolyte_inquiry(ctx)
    end
  end

  defp explain_the_screams(ctx) do
    ctx
    |> next()
    |> mes(speaker_name(ctx))
    |> mes("I heard screams")
    |> mes("from outside! Did")
    |> mes("something happen?")
    |> next()
    |> mes("[Minister]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Minister]")
    |> mes(
      "Ah, there are a few stray cats running around, those Wild Roses, so those noises you heard must have been them. Everything is fine here in the palace."
    )
    |> set_char_var(:tu_archer02, 6)
  end

  defp cold_refusal(ctx) do
    ctx
    |> next()
    |> mes("^3355FFThe urgency that the Minister expressed earlier has been")
    |> mes(
      "replaced with a stone cold feeling of sternness. He probably won't tell you much more information,"
    )
    |> mes("no matter how much you ask him.")
  end

  defp acolyte_inquiry(ctx) do
    if get_char_var(ctx, :tu_acolyte01, 0) == 25 do
      ctx
      |> next()
      |> mes(speaker_name(ctx))
      |> mes("Um...")
      |> mes("I hear that")
      |> mes("the royal family")
      |> mes("might be in sort of")
      |> mes("trouble. Is there any")
      |> mes("way I could help?")
      |> next()
      |> mes("[Minister]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Minister]")
      |> mes("You must be mistaken.")
      |> mes("The royal family is fine,")
      |> mes("especially since our")
      |> mes("kingdom is at peace.")
      |> next()
      |> mes("[Minister]")
      |> mes(
        "Perhaps you've gotten that idea because it's very difficult to meet any member of the royal family. Please understand that they're"
      )
      |> mes("all very busy trying to serve")
      |> mes("the people.")
      |> next()
      |> mes("[Minister]")
      |> mes(
        "As a holy servant, I'm sure that you'll find plenty of other people who have need of your help and abilities outside of the palace."
      )
    else
      ctx
    end
  end

  defp speaker_name(ctx), do: Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]")
end
