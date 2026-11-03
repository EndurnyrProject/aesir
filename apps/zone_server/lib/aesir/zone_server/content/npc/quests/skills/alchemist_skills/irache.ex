defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Irache do
  @moduledoc """
  A Juno researcher whose all-dissolving formula burns through its own test tube.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG
    - Toms
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 22,
        y: 107,
        dir: 5,
        sprite: 740,
        name: "Irache",
        scope: :shared,
        unique_name: "Irache#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Irache]")
    |> mes("Heh heh heh...!")
    |> mes("It's done! With this")
    |> mes("formula, I can melt any")
    |> mes("substance in the world!")
    |> mes("Hahahaha! Nothing stands")
    |> mes("between me and world domi--")
    |> next()
    |> mes("[Irache]")
    |> mes("OWWWW!")
    |> mes("The secret formula!")
    |> mes("It's burning through")
    |> mes("the test tube! I've made")
    |> mes("it too powerful! Confound it!")
    |> close()
  end
end
