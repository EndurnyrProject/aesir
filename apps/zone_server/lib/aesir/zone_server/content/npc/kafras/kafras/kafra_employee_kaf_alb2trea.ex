defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafAlb2trea do
  @moduledoc """
  Kafra employee who runs the Kafra services at Sunken Ship.

  ## Behavior

  - Greets the player with the branch cutin and the branch welcome, then opens the
    shared Kafra menu with this branch's fees and available services.
  - On the save option, stores the respawn point for this location and closes with the
    branch farewell.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - kobra_k88
    - Samuray22
    - Evera
    - Lupus
    - Euphy
    - Lemongrass

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/kafras.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alb2trea",
        x: 59,
        y: 69,
        dir: 5,
        sprite: 117,
        name: "Kafra Employee::kaf_alb2trea",
        scope: :shared,
        unique_name: "kaf_alb2trea"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FKafend
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafra
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> cutin("kafra_01", 2)
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("The Kafra services")
      |> mes("are always on your side.")
      |> mes("How may I assist you?")
      |> FKafra.call([5, 2, 1, 50, 0])

    ctx
    |> savepoint("alb2trea", 92, 64)
    |> FKafend.call([0, 1, "at Sunken Ship"])
  end
end
