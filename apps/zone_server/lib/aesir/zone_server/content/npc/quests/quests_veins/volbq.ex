defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Volbq do
  @moduledoc """
  Warns players approaching the high priest.

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
        map: "thor_camp",
        x: 62,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#volbq",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    ctx
    |> mes("^3355FFThere is an old man")
    |> mes("in high priest robes")
    |> mes("in front of you.^000000")
    |> next()
    |> mes("^3355FFYou'd better not")
    |> mes("do anything too")
    |> mes("conspicuous in")
    |> mes("front of him.^000000")
    |> close()
  end
end
