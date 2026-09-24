defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.HunterInfo do
  @moduledoc """
  Notice announcing that the Hunter job change has moved to Hugel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_hunter",
        x: 99,
        y: 99,
        dir: 4,
        sprite: 727,
        name: "Hunter Info",
        scope: :shared,
        unique_name: "HntNotice"
      },
      %{
        map: "pay_fild10",
        x: 148,
        y: 252,
        dir: 3,
        sprite: 857,
        name: "Job Change Location",
        scope: :shared,
        unique_name: "Job Change Location#hu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("============ Notice ============")
    |> mes("We would like to inform that the Hunter Job Change Location")
    |> mes("has been moved to ^ff0000Hugel^000000 in the Schwarzwald Republic.")
    |> next()
    |> mes("You can now use the Hugel airline, so please use the airship to visit Hugel.")
    |> next()
    |> mes("You will find the new Job Change Location at ^ff0000 Hugel 208 222 ^000000.")
    |> next()
    |> mes("^804000(You found a tiny line written at the end of the notice.)^000000")
    |> mes(" ")
    |> mes(" ")
    |> mes(" ")
    |> mes("I, the Falcon breeder have moved out as well.")
    |> close()
  end
end
