defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Larjes do
  @moduledoc """
  Larjes warns adventurers about a dangerous creature.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nameless_in",
        x: 13,
        y: 58,
        dir: 6,
        sprite: 97,
        name: "Larjes",
        scope: :shared,
        unique_name: "Larjes#Monastery"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  end

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Larjes]")
    |> mes("Be careful. That guy")
    |> mes("looks pretty dangerous.")
    |> close()
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Larjes#Monastery")
  end
end
