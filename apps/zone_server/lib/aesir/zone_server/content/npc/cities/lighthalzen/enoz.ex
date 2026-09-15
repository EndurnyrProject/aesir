defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Enoz do
  @moduledoc """
  Discusses Enoz's newly arrived novel from Rune-Midgarts.

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
        x: 139,
        y: 40,
        dir: 7,
        sprite: 53,
        name: "Enoz",
        scope: :shared,
        unique_name: "Enoz#oz"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Enoz]")
    |> mes("So, the novel I ordered from")
    |> mes("the Rune-Midgarts Kingdom")
    |> mes("just recently arrived. It's real good, by the guy who wrote")
    |> mes("''Roda Frog Adventure''")
    |> mes("years ago. Remember?")
    |> next()
    |> mes("[Enoz]")
    |> mes("Anyway, this new book,")
    |> mes("''Where the Red Plant Grows''")
    |> mes("is up for the Yggdrasilberry")
    |> mes("Award. I... I don't know why")
    |> mes("I was compelled to share that")
    |> mes("with you. Seriously, I don't...")
    |> close()
  end
end
