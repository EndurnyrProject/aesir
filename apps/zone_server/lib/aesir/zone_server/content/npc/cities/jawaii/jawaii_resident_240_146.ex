defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.JawaiiResident240146 do
  @moduledoc """
  Welcomes honeymooners and describes Jawaii's wildlife.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 240,
        y: 146,
        dir: 5,
        sprite: 724,
        name: "Jawaii Resident",
        scope: :shared,
        unique_name: "Jawaii Resident#desc1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Waii Waii]")
    |> mes("Welcome to Jawaii!")
    |> next()
    |> mes("[Waii Waii]")
    |> mes("Here, you can enjoy your")
    |> mes(
      "honeymoon without worrying about any interruptions. You don't even have to bother with that notorious Single Army!"
    )
    |> next()
    |> mes("[Waii Waii]")
    |> mes(
      "Well, there are a few monsters around, but you'll be okay as long as you don't attack them first. Think of them as the original residents of this island, another sight to enjoy."
    )
    |> close()
  end
end
