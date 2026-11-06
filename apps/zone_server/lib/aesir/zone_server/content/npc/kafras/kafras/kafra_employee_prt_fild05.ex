defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeePrtFild05 do
  @moduledoc """
  Kafra employee who runs the Kafra services at the Prontera Culverts.

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
        map: "prt_fild05",
        x: 290,
        y: 224,
        dir: 3,
        sprite: 114,
        name: "Kafra Employee::prt_fild05",
        scope: :shared,
        unique_name: "prt_fild05"
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
      |> FKafra.call([5, 1, 1, 40, 0])

    ctx
    |> savepoint("prt_fild05", 274, 243)
    |> FKafend.call([0, 1, "at the Prontera Culverts"])
  end
end
