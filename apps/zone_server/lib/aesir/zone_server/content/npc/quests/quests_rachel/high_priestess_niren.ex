defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.HighPriestessNiren do
  @moduledoc """
  Controls Niren’s appearance during the temple conversation.

  ## Behavior

  - Hides Niren on initialization and after her appearance timer expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temin",
        x: 294,
        y: 149,
        dir: 0,
        sprite: 915,
        name: "High Priestess Niren",
        scope: :shared,
        unique_name: "High Priestess Niren#ra"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer120000", ctx), do: ev_ontimer120000(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "High Priestess Niren#ra")
  end

  def ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  def ev_ontimer120000(ctx) do
    ctx |> stopnpctimer() |> hideonnpc("High Priestess Niren#ra")
  end
end
