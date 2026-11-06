defmodule Aesir.ZoneServer.Content.Npc.Floating.KafIzlude do
  @moduledoc """
  Pre-renewal Kafra employee in Izlude who runs the Kafra services and saves the respawn point on
  whichever map she stands on.

  ## Behavior

  - Greets the player with the branch cutin and the branch welcome, then opens the shared Kafra
    menu with this branch's fees and available services.
  - On the save option, stores the respawn point on this NPC's own map and closes with the branch
    farewell.

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
        map: "izlude",
        x: 134,
        y: 87,
        dir: 3,
        sprite: 117,
        name: "Kafra Employee",
        scope: :pre_renewal,
        unique_name: "Kafra Employee#iz"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FKafend
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafra
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafset
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> cutin("kafra_01", 2)
      |> FKafset.call([])

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("The Kafra services")
      |> mes("are always on your side.")
      |> mes("How may I assist you?")
      |> FKafra.call([5, 0, 1, 40, 820])

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        savepoint(ctx, strnpcinfo(ctx, 4), 129, 97)
      else
        savepoint(ctx, "izlude", 94, 103)
      end

    FKafend.call(ctx, [0, 1, "in the city of Izlude"])
  end
end
