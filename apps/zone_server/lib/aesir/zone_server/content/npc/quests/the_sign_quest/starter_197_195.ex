defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Starter197195 do
  @moduledoc """
  Starts the witch’s timed encounter when a player enters the area.

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
        x: 197,
        y: 195,
        dir: 0,
        sprite: -1,
        name: "Starter",
        scope: :shared,
        unique_name: "Starter#witch",
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
    |> donpcevent("Timer#witch::OnStart")
    |> disablenpc("Starter#witch")
  end

  def ev_onenable(ctx), do: enablenpc(ctx, "Starter#witch")
end
