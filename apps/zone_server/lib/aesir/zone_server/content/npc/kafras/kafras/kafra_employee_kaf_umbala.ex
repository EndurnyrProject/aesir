defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafUmbala do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Umbala.

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
        map: "umbala",
        x: 87,
        y: 160,
        dir: 4,
        sprite: 721,
        name: "Kafra Employee::kaf_umbala",
        scope: :shared,
        unique_name: "kaf_umbala"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FKafend
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafra
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafset
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> cutin("kafra_07", 2)
      |> FKafset.call([])

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("You know that our")
      |> mes("service is always")
      |> mes("on your side~")
      |> FKafra.call([5, 0, 1, 80, 0])

    ctx
    |> savepoint("umbala", 126, 131)
    |> FKafend.call([0, 1, "in the city of Umbala"])
  end
end
