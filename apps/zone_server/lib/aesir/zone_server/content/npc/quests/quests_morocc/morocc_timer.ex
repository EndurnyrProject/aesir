defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.MoroccTimer do
  @moduledoc """
  A trigger starts the Satan Morocc broadcast once.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "moc_fild21",
        x: 38,
        y: 193,
        dir: 0,
        sprite: -1,
        name: "Morocc Timer",
        scope: :shared,
        unique_name: "Morocc Timer#edq",
        trigger: {6, 6}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if get_server_temp_var(ctx, "re_moc", 0) == 0 do
      ctx |> set_server_temp_var("re_moc", 1) |> donpcevent("Satan Broadcast#edq::OnEnable")
    else
      ctx
    end
  end
end
