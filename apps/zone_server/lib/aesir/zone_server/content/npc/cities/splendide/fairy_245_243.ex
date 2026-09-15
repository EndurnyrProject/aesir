defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy245243 do
  @moduledoc """
  A fairy discusses Splendide's restoration and conflict with the Saphas.

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
        x: 245,
        y: 243,
        dir: 3,
        sprite: 462,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("This land was such a waste land.")
      |> mes("It was extremely cold and")
      |> mes("nothing could live here.")
      |> mes("but, once we inhabited this place, it has been changing day by day.")
      |> next()
      |> mes("[Fairy]")
      |> mes("Now, all the problems are gone.")
      |> mes("Except those ugly fat Saphas.")
      |> mes("How can we be rid of those things?")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("DiebVohlWeh Ko RasVeldFar Ie AshVohl")
      |> mes("neaAmanIman Ie DorDuMe No Hireo")
      |> mes("tassermaur Yee DorAdorNud Ee ")
      |> mes("NohThorVe O FusImanAman")
      |> next()
      |> mes("[Fairy]")
      |> mes("OsaVeldWeh U GothIyazVer Or ")
      |> mes("LarsAnDor Yee TurVeldVil")
      |> mes("LarsDanaFus An DiebImanmar er Dim")
      |> mes("tasLoRini Ir WehAndu")
      |> close()
    end
  end
end
