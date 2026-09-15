defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.BankriKun do
  @moduledoc """
  Offers Bankri Kun's tired and unconventional adventuring advice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 134,
        y: 38,
        dir: 3,
        sprite: 798,
        name: "Bankri Kun",
        scope: :shared,
        unique_name: "Bankri Kun#kagun"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bankri Kun]")
    |> mes("Must work...")
    |> mes("Must focus...")
    |> mes("Resist sleepiness...")
    |> mes("Why do I keep coming")
    |> mes("here? Ugh, h-horrible.")
    |> next()
    |> mes("[Bankri Kun]")
    |> mes("Hey youngster. You wanted")
    |> mes("adventuring advice? Okay.")
    |> mes("Um. Hm. Always. Brush.")
    |> mes("Your teeth. Brush them")
    |> mes("everyday. Oh, and don't")
    |> mes("forget to floss, either.")
    |> next()
    |> mes("[Bankri Kun]")
    |> mes("Now it's time for me")
    |> mes("to head back to work.")
    |> mes("I'll see you later, kid.")
    |> mes("Sorry my advice was so")
    |> mes("lame-- I couldn't think of")
    |> mes("anything else to tell you.")
    |> close()
  end
end
