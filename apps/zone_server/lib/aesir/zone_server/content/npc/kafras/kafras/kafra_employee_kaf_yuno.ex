defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafYuno do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Juno.

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
        map: "yuno",
        x: 152,
        y: 187,
        dir: 4,
        sprite: 860,
        name: "Kafra Employee::kaf_yuno",
        scope: :shared,
        unique_name: "kaf_yuno"
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
      |> cutin("kafra_08", 2)
      |> FKafset.call([])

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("The Kafra Corporation")
      |> mes("is always working to provide")
      |> mes("you with convenient services.")
      |> mes("How may I be of assistance?")
      |> FKafra.call([5, 0, 0, 40, 800])

    ctx
    |> savepoint("yuno", 158, 125)
    |> FKafend.call([0, 1, "in the city of Juno"])
  end
end
