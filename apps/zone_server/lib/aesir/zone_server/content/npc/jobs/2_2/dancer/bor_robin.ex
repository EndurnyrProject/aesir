defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.BorRobin do
  @moduledoc """
  Comodo theater fan who offers to take visitors to the Dancer job change area.

  ## Behavior

  - Warps the player to the Dancer job change area on request.

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
        x: 193,
        y: 151,
        dir: 4,
        sprite: 86,
        name: "Bor Robin",
        scope: :shared,
        unique_name: "Bor Robin#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bor Robin]")
      |> mes("Aah....")
      |> mes("A prima donna")
      |> mes("in the spotlight!")
      |> mes("I'll be able to watch them become Dancers right before my eyes...!")
      |> next()
      |> mes("[Bor Robin]")
      |> mes("It's great to be")
      |> mes("a man in this day and age! Hurray for the Comodo Theater!")
      |> next()
      |> mes("[Bor Robin]")
      |> mes("Mm?")
      |> mes("You want")
      |> mes("to go, too?")
      |> mes("It's a good opportunity to watch the Dancer job change test.")
      |> next()
      |> select(["Go to the Job Change Area", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Bor Robin]")
      |> mes("Yaay~~")
      |> mes("Let's go!")
      |> close()
      |> warp("job_duncer", 70, 49)
    else
      ctx
      |> mes("[Bor Robin]")
      |> mes("Huh...")
      |> mes("Well, I can't")
      |> mes("help it if you don't")
      |> mes("want to accompany me.")
      |> close()
    end
  end
end
