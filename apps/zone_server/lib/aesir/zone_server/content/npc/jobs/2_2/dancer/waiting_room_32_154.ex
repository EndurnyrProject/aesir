defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.WaitingRoom32154 do
  @moduledoc """
  Explains how to enter the Dancer job test waiting room.

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
        map: "job_duncer",
        x: 32,
        y: 154,
        dir: 1,
        sprite: 66,
        name: "Waiting Room",
        scope: :shared,
        unique_name: "Waiting Room#click"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Pyorgin]")
    |> mes("Please wait in")
    |> mes("the waiting room.")
    |> mes("Click the Chatroom")
    |> mes("box to enter.")
    |> next()
    |> mes("[Pyorgin]")
    |> mes("Also, those who")
    |> mes("are curious about")
    |> mes("the test can watch")
    |> mes("backstage.")
    |> close()
  end
end
