defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.Gatekeeper do
  @moduledoc """
  Welcomes visitors to the Kunlun chief's residence and warns them to behave.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 113,
        y: 135,
        dir: 6,
        sprite: 780,
        name: "Gatekeeper",
        scope: :shared,
        unique_name: "Gatekeeper#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kunlun Guard]")
    |> mes("Welcome.")
    |> mes("This is the residence of Shi Yan Wen, the chief of Kunlun.")
    |> next()
    |> mes("[Kunlun Guard]")
    |> mes("You better behave yourself while")
    |> mes("you are here. If we see anything")
    |> mes("suspicious, we'll arrest you in a heartbeat.")
    |> next()
    |> mes("[Kunlun Guard]")
    |> mes("However, rest assured, you seem")
    |> mes("like a trustworthy person.")
    |> mes("I'm sure nothing will happen. Enjoy your visit.")
    |> close()
  end
end
