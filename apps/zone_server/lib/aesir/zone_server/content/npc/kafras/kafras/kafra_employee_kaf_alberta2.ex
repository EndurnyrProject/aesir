defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafAlberta2 do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Alberta.

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
        map: "alberta",
        x: 113,
        y: 60,
        dir: 6,
        sprite: 112,
        name: "Kafra Employee::kaf_alberta2",
        scope: :shared,
        unique_name: "kaf_alberta2"
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
      |> cutin("kafra_06", 2)
      |> FKafset.call([])

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation~")
      |> mes("The Kafra Services are")
      |> mes("always here to support")
      |> mes("you. So how can I be")
      |> mes("of service today?")
      |> FKafra.call([5, 0, 0, 50, 850])

    ctx
    |> savepoint("alberta", 117, 57)
    |> FKafend.call([0, 1, "in the city of Alberta"])
  end
end
