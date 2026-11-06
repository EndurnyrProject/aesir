defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployee do
  @moduledoc """
  Kafra employee who runs the Kafra services in the town of Einbech.

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
        map: "einbech",
        x: 181,
        y: 132,
        dir: 5,
        sprite: 860,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "kaf_einbech"
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
      |> cutin("kafra_08", 2)
      |> mes("[Kafra Employee]")
      |> mes("Welcome~!")
      |> mes("The Kafra Services")
      |> mes("are always on your side.")
      |> mes("So how can I help you?")
      |> FKafra.call([5, 4, 1, 40, 850])

    ctx
    |> savepoint("einbech", 182, 124)
    |> FKafend.call([0, 1, "in the town of Einbech"])
  end
end
