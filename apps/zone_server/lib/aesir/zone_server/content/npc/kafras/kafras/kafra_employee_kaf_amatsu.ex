defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafAmatsu do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Amatsu.

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
        map: "amatsu",
        x: 102,
        y: 149,
        dir: 4,
        sprite: 116,
        name: "Kafra Employee::kaf_amatsu",
        scope: :shared,
        unique_name: "kaf_amatsu"
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
      |> cutin("kafra_02", 2)
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("Kafra's Employees are")
      |> mes("always ready to serve you.")
      |> mes("How can I help you today?")
      |> FKafra.call([5, 3, 1, 50, 700])

    ctx
    |> savepoint("amatsu", 116, 94)
    |> FKafend.call([0, 1, "in the city of Amatsu"])
  end
end
