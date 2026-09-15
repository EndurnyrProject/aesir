defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy230142 do
  @moduledoc """
  A fairy boasts about being stunning.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped and the ep13_2_rhea gate is complete; otherwise
    responds in untranslated language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "splendide",
        x: 230,
        y: 142,
        dir: 3,
        sprite: 439,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx |> mes("[Fairy]") |> mes("Ah-Ha, I am so stunning.") |> close()
    else
      ctx |> mes("[Fairy]") |> mes("AgolWhaNe O LoRini") |> close()
    end
  end
end
