defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Stranger0 do
  @moduledoc """
  Schedules a randomized Stranger encounter after a monster dies.

  ## Credits

  - Original from rAthena, authors and Contributors
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
        map: "nyd_dun02",
        x: 206,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "Stranger",
        scope: :shared,
        unique_name: "Stranger#ep13_2_dan04"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnMyMobDead", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer300000", ctx), do: schedule_encounter(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  defp schedule_encounter(ctx) do
    ctx =
      if Rathena.truthy?(:rand.uniform(2) - 1) do
        enablenpc(ctx, "Stranger#ep13_2_dan02")
      else
        donpcevent(ctx, "Stranger#ep13_2_dan01::OnEnable")
      end

    stopnpctimer(ctx)
  end
end
