defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.SwitchOn do
  @moduledoc """
  Shows that the Juperos elevator switch is in use.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jupe_ele_r",
        x: 51,
        y: 98,
        dir: 0,
        sprite: 844,
        name: "Switch On",
        scope: :shared,
        unique_name: "Switch On#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFIt seems like")
    |> mes("someone else is")
    |> mes("using this machine...^000000")
    |> close()
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Switch On#ufe")
  end
end
