defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Mj1001T do
  @moduledoc """
  Restarts a quest marker after a one-minute timer.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_10",
        x: 1,
        y: 1,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj10_01_t"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer60000", ctx), do: ev_ontimer60000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  def ev_ontimer60000(ctx) do
    ctx |> enablenpc("#mj10_01") |> stopnpctimer()
  end
end
