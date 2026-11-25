defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LawEnforcement do
  @moduledoc """
  Law enforcement manages the gangster alert.

  ## Behavior

  - Spawns gangsters during an alert and clears them when the timer expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 111,
        name: "Law Enforcement",
        scope: :shared
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer220000", ctx), do: ev_ontimer220000(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_onenable(ctx) do
    ctx
    |> mapannounce(
      "lighthalzen",
      "Attention, citizens. Our security has been breached and the city is in Gangster Alert status. Please find shelter immediately!",
      1
    )
    |> initnpctimer()
    |> set_local(:i, 0)
    |> spawn_gangsters()
  end

  def ev_ontimer220000(ctx) do
    ctx
    |> killmonster("lighthalzen", "Law Enforcement::OnMyMobDead")
    |> mapannounce(
      "lighthalzen",
      "Attention, citizens. Our law enforcement department has successfully contained the situation. Alert status has been canceled.",
      1
    )
    |> set_server_temp_var("Lhz_Gangster_Alert", 0)
    |> stopnpctimer()
  end

  def ev_onmymobdead(ctx) do
    ctx
  end

  defp spawn_gangsters(ctx) do
    if get_local(ctx, :i, 0) < 30 do
      ctx =
        summon_mob(ctx,
          mob_id: 1592,
          map: "lighthalzen",
          at: :random,
          name: "Gangster",
          event: "Law Enforcement::OnMyMobDead"
        )

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> spawn_gangsters()
    else
      ctx
    end
  end
end
