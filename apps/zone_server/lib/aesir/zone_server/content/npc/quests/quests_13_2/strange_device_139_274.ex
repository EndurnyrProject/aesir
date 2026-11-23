defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.StrangeDevice139274 do
  @moduledoc """
  Controls the dungeon puzzle panels through a timed device.

  ## Behavior

  - Rejects activation while the device is already running.
  - Enables one of two random sets of panels and resets them after a timer.

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
        x: 139,
        y: 274,
        dir: 0,
        sprite: 844,
        name: "Strange Device",
        scope: :shared,
        unique_name: "Strange Device#ep13_in",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTimer70000", ctx) do
    ev_ontimer70000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_server_temp_var(ctx, "08_ep13nydun02_in", 0) == 1 do
      ctx
      |> mes("The device has already been activated.")
      |> mes("You must wait for the controls to reset.")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("There's a controllable device here.")
        |> mes("You might be able to control that device from here.")
        |> next()
        |> select(["Control.", "Quit."])

      case choice do
        1 -> activate(ctx)
        2 -> ctx |> mes("You decide not to control the device.") |> close()
        _ -> ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp activate(ctx) do
    if get_server_temp_var(ctx, "08_ep13nydun02_in", 0) == 1 do
      ctx |> mes("Seems to have been started.") |> close()
    else
      ctx =
        ctx
        |> set_server_temp_var("08_ep13nydun02_in", 1)
        |> set_local(:way_loot, Enum.random(1..2))

      ctx =
        if get_local(ctx, :way_loot, 0) == 1 do
          ctx
          |> donpcevent("ep13_warp_s1::OnEnable")
          |> donpcevent("ep13_warp_11::OnEnable")
          |> donpcevent("ep13_warp_21::OnEnable")
          |> donpcevent("ep13_warp_22::OnEnable")
          |> donpcevent("ep13_warp_22_2::OnEnable")
        else
          ctx
          |> donpcevent("ep13_warp_s3::OnEnable")
          |> donpcevent("ep13_warp_13::OnEnable")
          |> donpcevent("ep13_warp_14::OnEnable")
          |> donpcevent("ep13_warp_24::OnEnable")
          |> donpcevent("ep13_warp_24_2::OnEnable")
        end

      ctx
      |> initnpctimer()
      |> mes("The device is now on.")
      |> mes("Panels have appeared across the ledge.")
      |> close()
    end
  end

  def ev_ontimer70000(ctx) do
    ctx
    |> donpcevent("ep13_nd2f_mng::OnReset")
    |> set_server_temp_var("08_ep13nydun02_in", 0)
    |> stopnpctimer()
  end

  def ev_ontouch(ctx) do
    specialeffect(ctx, :level99_4)
  end
end
