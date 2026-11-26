defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Timer do
  @moduledoc """
  Controls the Serin encounter timer.

  ## Behavior

  - Enables the exit after ten minutes, then resets the encounter and stops the timer.

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
        x: 1,
        y: 0,
        dir: 0,
        sprite: -1,
        name: "Timer",
        scope: :shared,
        unique_name: "Timer#serin"
      }
    ]

  @impl true
  def on_event("OnStart", ctx), do: ev_onstart(ctx)
  def on_event("OnTimer600000", ctx), do: ev_ontimer600000(ctx)
  def on_event("OnTimer620000", ctx), do: ev_ontimer620000(ctx)
  @impl true
  def on_talk(ctx), do: ev_onstart(ctx)

  def ev_onstart(ctx), do: initnpctimer(ctx)

  def ev_ontimer600000(ctx) do
    donpcevent(ctx, "Warp#serin::OnEnable")
  end

  def ev_ontimer620000(ctx) do
    ctx
    |> set_server_temp_var("sign_w2", 0)
    |> donpcevent("Starter#serin::OnEnable")
    |> donpcevent("Warp#serin::OnDisable")
    |> donpcevent("Serin#serin::OnEnable")
    |> donpcevent("Dark Lord#serin::OnDisable")
    |> donpcevent("Serin#dummy::OnDisable")
    |> donpcevent("CallMonster#serin::OnReset")
    |> stopnpctimer()
  end
end
