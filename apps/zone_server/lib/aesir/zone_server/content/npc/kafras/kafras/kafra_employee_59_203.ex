defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployee59203 do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Einbroch.

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
        map: "einbroch",
        x: 59,
        y: 203,
        dir: 6,
        sprite: 861,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "kaf_einbroch2"
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
      |> cutin("kafra_09", 2)
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("The Kafra services")
      |> mes("are always on your side.")
      |> mes("How may I assist you?")
      |> FKafra.call([5, 4, 1, 50, 800])

    ctx
    |> savepoint("einbroch", 240, 197)
    |> FKafend.call([0, 1, "in the city of Einbroch"])
  end
end
