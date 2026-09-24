defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Sonotora do
  @moduledoc """
  Comodo local who daydreams about joining the dance school.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 180,
        y: 153,
        dir: 4,
        sprite: 90,
        name: "Sonotora",
        scope: :shared,
        unique_name: "Sonotora#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Athena Sonotora]")
    |> mes("They say the")
    |> mes("famous dance school")
    |> mes("here in Comodo is going")
    |> mes("to open soon.")
    |> next()
    |> mes("[Athena Sonotora]")
    |> mes("Aah...")
    |> mes("To be a prima donna")
    |> mes("in the spotlight!")
    |> next()
    |> mes("[Athena Sonotora]")
    |> mes("I want to sign up too,")
    |> mes("but the requirements are")
    |> mes("so specific. I wonder if")
    |> mes("I should just try anyways...")
    |> close()
  end
end
