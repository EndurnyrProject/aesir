defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Izlude.CuskoalIzlude do
  @moduledoc """
  Cuskoal, an Izlude resident who talks about the Arena or the Prontera pubs.

  ## Behavior

  - Picks one of two topics per interaction: the Izlude Arena challenge, or
    Prontera's pubs as a place to gather rumors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 174,
        y: 164,
        dir: 4,
        sprite: 124,
        name: "Cuskoal",
        scope: :renewal,
        unique_name: "Cuskoal#izlude"
      },
      %{
        map: "izlude_a",
        x: 174,
        y: 164,
        dir: 4,
        sprite: 124,
        name: "Cuskoal",
        scope: :renewal,
        unique_name: "Cuskoal#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 174,
        y: 164,
        dir: 4,
        sprite: 124,
        name: "Cuskoal",
        scope: :renewal,
        unique_name: "Cuskoal#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 174,
        y: 164,
        dir: 4,
        sprite: 124,
        name: "Cuskoal",
        scope: :renewal,
        unique_name: "Cuskoal#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 174,
        y: 164,
        dir: 4,
        sprite: 124,
        name: "Cuskoal",
        scope: :renewal,
        unique_name: "Cuskoal#izlude_d"
      },
      %{
        map: "izlude",
        x: 119,
        y: 121,
        dir: 2,
        sprite: 124,
        name: "Cuskoal",
        scope: :pre_renewal,
        unique_name: "Cuskoal#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Cuskoal]")

    case :rand.uniform(2) - 1 do
      1 -> about_the_arena(ctx)
      _ -> about_the_pubs(ctx)
    end
  end

  defp about_the_arena(ctx) do
    ctx
    |> mes(
      "The Arena here is THE place for capable young people from all over the Rune-Midgarts Kingdom to challenge themselves and test their skills."
    )
    |> next()
    |> mes("[Cuskoal]")
    |> mes(
      "You can battle with monsters of differing levels. So, the number of stages you survive will be a testament to your battle prowess."
    )
    |> next()
    |> mes("[Cuskoal]")
    |> mes("So, whaddya say?")
    |> close()
  end

  defp about_the_pubs(ctx) do
    ctx
    |> mes(
      "The pubs in Prontera are always full of people from local areas and from out-of-town. It can get pretty busy."
    )
    |> next()
    |> mes("[Cuskoal]")
    |> mes("It's a pretty good place to stop by for general information and to listen to rumors.")
    |> next()
    |> mes("[Cuskoal]")
    |> mes(
      "So if you listen carefully, you just might get lucky and learn some very useful information for yourself."
    )
    |> close()
  end
end
