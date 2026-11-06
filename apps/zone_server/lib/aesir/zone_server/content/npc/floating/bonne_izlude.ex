defmodule Aesir.ZoneServer.Content.Npc.Floating.BonneIzlude do
  @moduledoc """
  Bonne, the Izlude greeter who introduces the satellite city of Prontera.

  ## Behavior

  - Describes Izlude's role as the kingdom's coastal watch and home of the
    Swordsman Association, and reassures the player about the bridge.

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
        x: 71,
        y: 92,
        dir: 2,
        sprite: 90,
        name: "Bonne",
        scope: :renewal,
        unique_name: "Bonne#izlude"
      },
      %{
        map: "izlude_a",
        x: 71,
        y: 92,
        dir: 2,
        sprite: 90,
        name: "Bonne",
        scope: :renewal,
        unique_name: "Bonne#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 71,
        y: 92,
        dir: 2,
        sprite: 90,
        name: "Bonne",
        scope: :renewal,
        unique_name: "Bonne#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 71,
        y: 92,
        dir: 2,
        sprite: 90,
        name: "Bonne",
        scope: :renewal,
        unique_name: "Bonne#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 71,
        y: 92,
        dir: 2,
        sprite: 90,
        name: "Bonne",
        scope: :renewal,
        unique_name: "Bonne#izlude_d"
      },
      %{
        map: "izlude",
        x: 55,
        y: 74,
        dir: 2,
        sprite: 90,
        name: "Bonne",
        scope: :pre_renewal,
        unique_name: "Bonne#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bonne]")
    |> mes("Greetings!")
    |> mes("Izlude welcomes you.")
    |> next()
    |> mes("[Bonne]")
    |> mes("Izlude is the satellite city of Prontera, capital of the Rune-Midgarts kingdom.")
    |> next()
    |> mes("[Bonne]")
    |> mes(
      "Izlude is key to our kingdom because of the Swordsman Association located here, as well as the fact that Izlude is in charge of protecting the Rune-Midgarts coastline."
    )
    |> next()
    |> mes("[Bonne]")
    |> mes(
      "I know, this bridge might look weak and fragile, but it is actually state of the art, built with the most sophisticated technology."
    )
    |> next()
    |> mes("[Bonne]")
    |> mes(
      "No matter how strong storms may be, or how many people may stand on it, this bridge will NEEEEVER collapse."
    )
    |> next()
    |> mes("[Bonne]")
    |> mes("Please enjoy")
    |> mes("your visit")
    |> mes("here in Izlude.")
    |> close()
  end
end
