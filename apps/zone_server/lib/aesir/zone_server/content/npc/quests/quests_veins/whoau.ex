defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Whoau do
  @moduledoc """
  A house owner reacts to an intruder.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 302,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#whoau",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    ctx =
      ctx
      |> mes("[House Owner]")
      |> mes("Wh-who the hell")
      |> mes("are you? Honey!")
      |> mes("There's this...")
      |> mes("person in our home!")
      |> next()
      |> mes("^3355FFHubbie never came.")
      |> mes("Nobody messes with")

    ctx
    |> mes("#{char_name(ctx, 0)}. Nobody.^000000")
    |> close()
  end
end
