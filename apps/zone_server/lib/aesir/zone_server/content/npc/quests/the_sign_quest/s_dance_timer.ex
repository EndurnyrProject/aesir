defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.SDanceTimer do
  @moduledoc """
  Runs the timed dance test sequence.

  ## Behavior

  - Announces each sequence and activates its first marker.
  - Resets the markers and re-enables the examiner when the test ends.

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
      %{map: "cmd_in01", x: 1, y: 1, dir: 0, sprite: -1, name: "s_dance_timer", scope: :shared}
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnButton_Off", ctx), do: ev_onbutton_off(ctx)
  def on_event("OnDisableAll", ctx), do: disable_all(ctx)
  def on_event("OnTimer2000", ctx), do: ev_ontimer2000(ctx)
  def on_event("OnTimer4000", ctx), do: ev_ontimer4000(ctx)
  def on_event("OnTimer6000", ctx), do: ev_ontimer6000(ctx)
  def on_event("OnTimer8000", ctx), do: ev_ontimer8000(ctx)
  def on_event("OnTimer11000", ctx), do: ev_ontimer11000(ctx)
  def on_event("OnTimer13000", ctx), do: ev_ontimer13000(ctx)
  def on_event("OnTimer18000", ctx), do: ev_ontimer18000(ctx)
  def on_event("OnTimer21000", ctx), do: ev_ontimer21000(ctx)
  def on_event("OnTimer24000", ctx), do: ev_ontimer24000(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  def on_event("OnTimer34000", ctx), do: ev_ontimer34000(ctx)
  def on_event("OnTimer38000", ctx), do: ev_ontimer38000(ctx)
  def on_event("OnTimer44000", ctx), do: ev_ontimer44000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  def ev_ondisable(ctx) do
    stopnpctimer(ctx)
  end

  def ev_onbutton_off(ctx), do: disable_all(ctx)

  defp disable_all(ctx) do
    ctx
    |> donpcevent("s_dance#up::OnDisable")
    |> donpcevent("s_dance#down::OnDisable")
    |> donpcevent("s_dance#left::OnDisable")
    |> donpcevent("s_dance#right::OnDisable")
    |> donpcevent("s_dance#cen::OnDisable")
  end

  def ev_ontimer2000(ctx) do
    mapannounce(
      ctx,
      "cmd_in01",
      "The test will be begin shortly. Please do your best~",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer4000(ctx) do
    ctx
    |> mapannounce("cmd_in01", " UP LEFT", 1, "0xFFFF00")
    |> donpcevent("s_dance#up::OnUp")
    |> donpcevent("s_dance#up::OnEnable")
  end

  def ev_ontimer6000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN RIGHT", 1, "0xFFFF00")
    |> donpcevent("s_dance#down::OnUp")
    |> donpcevent("s_dance#down::OnEnable")
  end

  def ev_ontimer8000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN LEFT & UP RIGHT", 1, "0xFFFF00")
    |> donpcevent("s_dance#left::OnUp")
    |> donpcevent("s_dance#left::OnEnable")
  end

  def ev_ontimer11000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN RIGHT", 1, "0xFFFF00")
    |> donpcevent("s_dance#down::OnUp")
    |> donpcevent("s_dance#down::OnEnable")
  end

  def ev_ontimer13000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN LEFT & UP RIGHT & UP LEFT & STAY CENTER", 1, "0xFFFF00")
    |> donpcevent("s_dance#left::OnUp")
    |> donpcevent("s_dance#left::OnEnable")
  end

  def ev_ontimer18000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN LEFT & DOWN RIGHT & DOWN LEFT", 1, "0xFFFF00")
    |> donpcevent("s_dance#left::OnUp")
    |> donpcevent("s_dance#left::OnEnable")
  end

  def ev_ontimer21000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN RIGHT & CENTER & DOWN RIGHT", 1, "0xFFFF00")
    |> donpcevent("s_dance#down::OnUp")
    |> donpcevent("s_dance#down::OnEnable")
  end

  def ev_ontimer24000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce(
      "cmd_in01",
      " DOWN LEFT & UP LEFT & UP RIGHT & DOWN RIGHT & CENTER",
      1,
      "0xFFFF00"
    )
    |> donpcevent("s_dance#left::OnUp")
    |> donpcevent("s_dance#left::OnEnable")
  end

  def ev_ontimer30000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " DOWN LEFT & UP RIGHT & UP LEFT & DOWN RIGHT", 1, "0xFFFF00")
    |> donpcevent("s_dance#left::OnUp")
    |> donpcevent("s_dance#left::OnEnable")
  end

  def ev_ontimer34000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce("cmd_in01", " UP RIGHT & DOWN RIGHT & UP RIGHT & DOWN RIGHT", 1, "0xFFFF00")
    |> donpcevent("s_dance#right::OnUp")
    |> donpcevent("s_dance#right::OnEnable")
  end

  def ev_ontimer38000(ctx) do
    ctx
    |> disable_all()
    |> mapannounce(
      "cmd_in01",
      " UP LEFT & UP RIGHT & CENTER & UP RIGHT & DOWN LEFT & DOWN RIGHT",
      1,
      "0xFFFF00"
    )
    |> donpcevent("s_dance#up::OnUp")
    |> donpcevent("s_dance#up::OnEnable")
  end

  def ev_ontimer44000(ctx) do
    ctx
    |> stopnpctimer()
    |> donpcevent("s_dance#up::OnReset")
    |> donpcevent("s_dance#down::OnReset")
    |> donpcevent("s_dance#left::OnReset")
    |> donpcevent("s_dance#right::OnReset")
    |> donpcevent("s_dance#cen::OnReset")
    |> mapannounce("cmd_in01", "Well done.", 1, "0xFFFF00")
    |> enablenpc("Examiner#sd")
    |> donpcevent("Standby Room#sign::OnReset")
  end
end
