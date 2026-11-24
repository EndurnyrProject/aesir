defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Stranger206114 do
  @moduledoc """
  Triggers a Dandelion encounter and controls its spawn.

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
        x: 206,
        y: 114,
        dir: 5,
        sprite: 456,
        name: "Stranger",
        scope: :shared,
        unique_name: "Stranger#ep13_2_dan02",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnCall", ctx), do: ev_oncall(ctx)
  def on_event("OnReset", ctx), do: ev_onreset(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  defp ev_oninit(ctx) do
    ev_ondisable(ctx)
  end

  defp ev_ondisable(ctx) do
    disablenpc(ctx, "Stranger#ep13_2_dan02")
  end

  defp ev_onenable(ctx) do
    enablenpc(ctx, "Stranger#ep13_2_dan02")
  end

  defp ev_oncall(ctx) do
    summon_mob(ctx,
      mob_id: 2026,
      map: "nyd_dun02",
      at: {206, 114},
      name: "Runway Dandelion",
      event: "Stranger#ep13_2_dan04::OnMyMobDead"
    )
  end

  defp ev_onreset(ctx) do
    killmonster(ctx, "nyd_dun02", "Stranger#ep13_2_dan04::OnMyMobDead")
  end

  defp ev_ontouch(ctx) do
    ctx
    |> emotion(:surprise, playerattached(ctx))
    |> emotion(:huk)
    |> disablenpc("Stranger#ep13_2_dan02")
    |> donpcevent("Stranger#ep13_2_dan01::OnCall")
  end
end
