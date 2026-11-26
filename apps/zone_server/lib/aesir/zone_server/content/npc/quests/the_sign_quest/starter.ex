defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Starter do
  @moduledoc """
  Starts Serin’s timed encounter when a player enters the area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_sign01",
        x: 196,
        y: 44,
        dir: 0,
        sprite: -1,
        name: "Starter",
        scope: :shared,
        unique_name: "Starter#serin",
        trigger: {32, 32}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    ctx
    |> donpcevent("Timer#serin::OnStart")
    |> disablenpc("Starter#serin")
  end

  def ev_onenable(ctx), do: enablenpc(ctx, "Starter#serin")
end
