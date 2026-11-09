defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Moc2EventOn do
  @moduledoc """
  The invisible trigger of the Morocc hideout's escape sequence, which runs the timers of
  Rin's rescue.

  ## Behavior

  - Reveals itself when enabled and on a click, and hides itself when disabled.
  - On touch, at `mao_morocc2` step 10, hides itself, starts the event controller and its timer;
    on any other step it repels the player back to Morocc.
  - At five and 5:03 minutes announces the voices through the hideout, at 5:06 warps the hideout
    to the camp, at 5:07 clears every actor of the scene, and at 5:08 reveals itself again and
    stops the timer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_dan01",
        x: 32,
        y: 27,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#moc2_event_on",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "#moc2_event_on"
  @map "que_dan01"
  @event_controller "#moc2_event01"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: enablenpc(ctx, @npc)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnStop", ctx), do: stopnpctimer(ctx)
  def on_event("OnTimer300000", ctx), do: announce(ctx, "...Hey-!!... Where are you?!!.... Hey-!")
  def on_event("OnTimer303000", ctx), do: announce(ctx, "...Isn't this voice...? ...Kidd?")
  def on_event("OnTimer306000", ctx), do: mapwarp(ctx, @map, "mid_camp", 205, 312)
  def on_event("OnTimer307000", ctx), do: clear_hideout(ctx)

  def on_event("OnTimer308000", ctx) do
    ctx
    |> enablenpc(@npc)
    |> set_server_temp_var("moc_mao_gate1", 0)
    |> stopnpctimer()
  end

  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) == 10 do
      ctx
      |> disablenpc(@npc)
      |> donpcevent("#{@event_controller}::OnEnable")
      |> initnpctimer()
    else
      repelled(ctx)
    end
  end

  defp announce(ctx, line), do: mapannounce(ctx, @map, line, 1, "0xdda0dd")

  defp repelled(ctx) do
    ctx
    |> mes(
      "A mysterious force is repelling you, and you're unable to push forward into this area."
    )
    |> close()
    |> warp("morocc", 100, 100)
    |> set_server_temp_var("moc_mao_gate1", 0)
  end

  defp clear_hideout(ctx) do
    ctx
    |> donpcevent("Corpse#moc2_dead01::OnDisable")
    |> donpcevent("Rin#moc2_bt_rin01::OnDisable")
    |> donpcevent("Rin#moc2_bt_rin02::OnDisable")
    |> donpcevent("Rayan#moc2_bt_r01::OnDisable")
    |> donpcevent("Dandelion Member#moc2_1::OnDisable")
    |> donpcevent("Dandelion Member#moc2_2::OnDisable")
    |> donpcevent("Dandelion Member#moc2_3::OnDisable")
    |> donpcevent("Dandelion Member#moc2_4::OnDisable")
    |> donpcevent("Dandelion Member#moc2_5::OnDisable")
    |> donpcevent("#{@event_controller}::OnDisable")
    |> donpcevent("Corpse#moc2_dead01::OnReset")
  end
end
