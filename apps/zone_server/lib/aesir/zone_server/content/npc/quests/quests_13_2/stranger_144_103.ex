defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Stranger144103 do
  @moduledoc """
  Restarts a Dandelion encounter after its monster dies.

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
        map: "nyd_dun02",
        x: 144,
        y: 103,
        dir: 0,
        sprite: -1,
        name: "Stranger",
        scope: :shared,
        unique_name: "Stranger#ep13_2_dan03"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnMyMobDead", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer300000", ctx) do
    ctx =
      if Rathena.truthy?(:rand.uniform(2) - 1) do
        enablenpc(ctx, "Stranger#ep13_2_dan01")
      else
        donpcevent(ctx, "Stranger#ep13_2_dan02::OnEnable")
      end

    stopnpctimer(ctx)
  end

  @impl true
  def on_talk(ctx), do: ctx
end
