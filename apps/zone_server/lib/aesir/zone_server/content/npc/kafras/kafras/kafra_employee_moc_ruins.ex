defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeMocRuins do
  @moduledoc """
  Kafra employee who runs the Kafra services at the Pyramids.

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
        map: "moc_ruins",
        x: 59,
        y: 157,
        dir: 5,
        sprite: 114,
        name: "Kafra Employee::moc_ruins",
        scope: :shared,
        unique_name: "moc_ruins"
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
      |> mes("[Kafra Employee]")
      |> mes("Welcome!")
      |> mes("The Kafra Corporation")
      |> mes("will always support the")
      |> mes("adventurers of Rune-Midgarts")
      |> mes("with its excellent service. So")
      |> mes("what can I do for you today?")
      |> FKafra.call([5, 2, 1, 90, 1200])

    ctx
    |> savepoint("moc_ruins", 41, 141)
    |> FKafend.call([0, 1, "at the Pyramids"])
  end
end
