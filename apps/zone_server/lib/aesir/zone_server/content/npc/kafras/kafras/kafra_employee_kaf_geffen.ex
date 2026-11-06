defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafGeffen do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Geffen.

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
        map: "geffen",
        x: 120,
        y: 62,
        dir: 0,
        sprite: 115,
        name: "Kafra Employee::kaf_geffen",
        scope: :shared,
        unique_name: "kaf_geffen"
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
      |> cutin("kafra_03", 2)
      |> FKafset.call([])

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome~!")
      |> mes("The Kafra Services")
      |> mes("are always on your side.")
      |> mes("So how can I help you?")
      |> FKafra.call([5, 0, 0, 30, 750])

    ctx
    |> savepoint("geffen", 119, 40)
    |> FKafend.call([0, 1, "in the city of Geffen"])
  end
end
