defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.SommonThanatos do
  @moduledoc """
  Summons Thanatos Phantom and starts the cooldown after its defeat.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thana_boss",
        x: 141,
        y: 218,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sommon_thanatos"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnMyMobDead", ctx) do
    ev_onmymobdead(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ev_onenable(ctx) do
    ctx
    |> specialeffect(:mappillar2, :area, "#sommon_thanatos")
    |> specialeffect(:seismicweapon, :area, "#sommon_thanatos")
    |> summon_mob(
      mob_id: 1708,
      map: "thana_boss",
      at: {141, 218},
      name: "Thanatos Phantom",
      event: "#sommon_thanatos::OnMyMobDead"
    )
  end

  defp ev_onmymobdead(ctx) do
    if mobcount(ctx, "thana_boss", "#sommon_thanatos::OnMyMobDead") < 1 do
      ctx
      |> mapannounce(
        "thana_boss",
        "RAWWWWWWWWWWR........ This can't be.........................",
        1,
        "0xff0000"
      )
      |> donpcevent("#cooltime_thana::OnEnable")
      |> set_server_temp_var("thana_summon", 6)
    else
      ctx
    end
  end
end
