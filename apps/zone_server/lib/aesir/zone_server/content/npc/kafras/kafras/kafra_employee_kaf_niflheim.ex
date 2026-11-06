defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafNiflheim do
  @moduledoc """
  Kafra employee of Niflheim who runs the Kafra services through the shared Kafra menu.

  ## Behavior

  - Greets the player with the stuttering Niflheim welcome and opens the shared Kafra
    menu with this branch's fees and available services.
  - On the save option, stores the respawn point for this location and closes with the
    Niflheim farewell, which drains a quarter of the player's SP.

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
        map: "niflheim",
        x: 202,
        y: 180,
        dir: 3,
        sprite: 791,
        name: "Kafra Employee::kaf_niflheim",
        scope: :shared,
        unique_name: "kaf_niflheim"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FKafend
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafra
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    {ctx, _} = FKafra.call(ctx, [1, 2, 1, 150, 0])

    ctx
    |> savepoint("niflheim", 192, 182)
    |> FKafend.call([1, 1, "in the city of Niflheim"])
  end
end
