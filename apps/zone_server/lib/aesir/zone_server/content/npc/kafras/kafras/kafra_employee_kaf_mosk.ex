defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafMosk do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Moscovia.

  ## Behavior

  - Opens the shared Kafra menu directly, without the branch welcome, with this branch's fees
    and available services.
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
        map: "moscovia",
        x: 223,
        y: 191,
        dir: 3,
        sprite: 114,
        name: "Kafra Employee::kaf_mosk",
        scope: :shared,
        unique_name: "kaf_mosk"
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
      |> cutin("kafra_04", 2)
      |> FKafra.call([0, 3, 0, 80, 700])

    ctx
    |> savepoint("moscovia", 221, 194)
    |> FKafend.call([0, 1, "in the city of Moscovia"])
  end
end
