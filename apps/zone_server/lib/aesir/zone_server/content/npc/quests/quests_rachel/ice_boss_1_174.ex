defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.IceBoss1174 do
  @moduledoc """
  Controls the ice cave boss encounter and its reset.

  ## Behavior

  - Summons Ktullanux and opens the secret passage on its death.
  - Restores the flames after a two-hour cooldown.

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
        map: "ice_dun03",
        x: 1,
        y: 174,
        dir: 3,
        sprite: -1,
        name: "ice_boss",
        scope: :shared,
        unique_name: "ice_boss#on"
      }
    ]

  @impl true
  def on_event("OnStart", ctx), do: handle_start(ctx)
  def on_event("OnStartTimer", ctx), do: handle_starttimer(ctx)
  def on_event("OnStopTimer", ctx), do: handle_stoptimer(ctx)
  def on_event("OnMyMobDead", ctx), do: handle_mymobdead(ctx)
  def on_event("OnTimer7200000", ctx), do: handle_timer7200000(ctx)
  @impl true
  def on_talk(ctx) do
    handle_start(ctx)
  end

  defp handle_start(ctx) do
    summon_mob(ctx,
      mob_id: 1779,
      map: "ice_dun03",
      at: {150, 135},
      name: "Ktullanux",
      event: "ice_boss#on::OnMyMobDead"
    )
  end

  defp handle_starttimer(ctx) do
    initnpctimer(ctx)
  end

  defp handle_stoptimer(ctx) do
    stopnpctimer(ctx)
  end

  defp handle_mymobdead(ctx) do
    ctx
    |> mapannounce(
      "ice_dun03",
      "Oh, Odin! Please protect this place from Thor's fierce fire!",
      1,
      16_737_843
    )
    |> mapannounce("ice_dun03", "Pzzzzz...Pzzzz...", 1, 3_407_871)
    |> donpcevent("ice_boss#on::OnStartTimer")
    |> donpcevent("#ice_sec::OnStart")
  end

  defp handle_timer7200000(ctx) do
    ctx
    |> stopnpctimer()
    |> set_server_temp_var("ktullanux_summon", 0)
    |> hideoffnpc("Blazing Fire#ice1")
    |> hideoffnpc("Blazing Fire#ice2")
    |> hideoffnpc("Blazing Fire#ice3")
    |> hideoffnpc("Blazing Fire#ice4")
  end
end
