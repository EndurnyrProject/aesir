defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Yuna do
  @moduledoc """
  Critiques Prontera's statue of Odin as an inadequate likeness.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 149,
        y: 202,
        dir: 2,
        sprite: 700,
        name: "YuNa",
        scope: :shared,
        unique_name: "YuNa#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[YuNa]")
    |> mes("Behold...")
    |> mes("Mighty Odin!")
    |> mes("God of wisdom!")
    |> mes("God of war!")
    |> next()
    |> mes("[YuNa]")
    |> mes(
      "Here, in Rune-Midgarts, we serve Odin, the fearsome god who sacrificed one of his eyes in order to acquire wisdom."
    )
    |> next()
    |> mes("[YuNa]")
    |> mes(
      "The statue you see behind of me is a sculpture of mighty Odin. But, it's a shame because it's such a bad likeness."
    )
    |> next()
    |> mes("[YuNa]")
    |> mes(
      "I mean, this statue is totally different from our image of Odin. I guess the sculptor took too many artistic liberties."
    )
    |> next()
    |> mes("[YuNa]")
    |> mes(
      "I bet the first time you saw this statue, you thought, '^3355FFOh, what a nice muscle man on a horse^000000.'"
    )
    |> next()
    |> mes("[YuNA]")
    |> mes(
      "But this statue is obviously not muscular enough, not godly enough to fairly represent a god! Maybe if he had a halo?"
    )
    |> close()
  end
end
