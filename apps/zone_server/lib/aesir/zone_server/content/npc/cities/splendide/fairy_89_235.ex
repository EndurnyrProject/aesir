defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy89235 do
  @moduledoc """
  A singing fairy boasts about her voice and keeps the player away.

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
        x: 89,
        y: 235,
        dir: 5,
        sprite: 446,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Lalalalal~Lala~Lalala~")
      |> mes("Let's sing a song~!")
      |> mes("My voice is so fantastic!")
      |> next()
      |> mes("[Fairy]")
      |> mes("Don't even think about getting close to me!")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("WehVeldHir Or ThusNorAnu")
      |> mes("ReImanWos Yu marFuloNor Yee ")
      |> mes("SharneaVrum Ir Ruff")
      |> next()
      |> mes("[Fairy]")
      |> mes("BurKoWeh Ie nesThusLu Ee ")
      |> close()
    end
  end
end
