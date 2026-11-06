defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafPayon3 do
  @moduledoc """
  Kafra employee who runs the Kafra services at the Payon Dungeon.

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
        map: "pay_arche",
        x: 55,
        y: 123,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee::kaf_payon3",
        scope: :shared,
        unique_name: "kaf_payon3"
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
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("The Kafra services")
      |> mes("are always on your side.")
      |> mes("How may I assist you?")
      |> FKafra.call([5, 5, 1, 90, 1200])

    ctx
    |> savepoint("pay_arche", 49, 144)
    |> FKafend.call([0, 1, "at the Payon Dungeon"])
  end
end
