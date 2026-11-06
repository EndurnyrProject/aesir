defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraKafMorocc2 do
  @moduledoc """
  Kafra employee who runs the Kafra services in the city of Morocc.

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
        map: "morocc",
        x: 160,
        y: 258,
        dir: 4,
        sprite: 114,
        name: "Kafra::kaf_morocc2",
        scope: :shared,
        unique_name: "kaf_morocc2"
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
      |> cutin("kafra_04", 2)
      |> FKafset.call([])

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome!")
      |> mes("The Kafra Corporation")
      |> mes("will always support the")
      |> mes("adventurers of Rune-Midgarts")
      |> mes("with its excellent service. So")
      |> mes("what can I do for you today?")
      |> FKafra.call([5, 0, 0, 60, 930])

    ctx
    |> savepoint("morocc", 157, 272)
    |> FKafend.call([0, 1, "in the city of Morocc"])
  end
end
