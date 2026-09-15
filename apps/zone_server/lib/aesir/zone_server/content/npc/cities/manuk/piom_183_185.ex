defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Piom183185 do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

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
        map: "manuk",
        x: 183,
        y: 185,
        dir: 5,
        sprite: 454,
        name: "Piom",
        scope: :shared,
        unique_name: "Piom#ep13_2_3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Piom]")
      |> mes("Our lives exist for Saphas.")
      |> mes("On the other hand,")
      |> mes("Saphas lives exist for me.")
      |> mes("Hum hahaha!")
      |> next()
      |> mes("[Piom]")
      |> mes("We, Saphas are always together!")
      |> mes("Wherever we are!")
      |> mes("Cheer for Saphas!")
      |> close()
    else
      ctx
      |> mes("[Piom]")
      |> mes("Esd fas hdi as sp ad osd")
      |> mes("Ns id pie sj idf")
      |> mes("Rto osd ps ad ")
      |> mes("Mi sho oo pesd")
      |> next()
      |> mes("[Piom]")
      |> mes("N sd sou as d ")
      |> mes("Ma asd psh ds ii ")
      |> mes("Qso uf lj dhis id")
      |> close()
    end
  end
end
