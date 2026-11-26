defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.CharmStoneAdmintt01 do
  @moduledoc """
  Cycles the active charm stone crystals on a timer.

  ## Behavior

  - Cycles crystal groups through timed enable and disable events.

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
        map: "tha_t08",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Charm Stone Admintt01"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer1000", ctx), do: ev_ontimer1000(ctx)
  def on_event("OnTimer600000", ctx), do: ev_ontimer600000(ctx)
  def on_event("OnTimer1200000", ctx), do: ev_ontimer1200000(ctx)
  def on_event("OnTimer1800000", ctx), do: ev_ontimer1800000(ctx)
  def on_event("OnTimer2400000", ctx), do: ev_ontimer2400000(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  defp ev_oninit(ctx) do
    ev_onenable(ctx)
  end

  defp ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  defp ev_ontimer1000(ctx) do
    ctx
    |> donpcevent("Shining Crystal#tt_r1::OnEnable")
    |> donpcevent("Shining Crystal#tt_g1::OnEnable")
    |> donpcevent("Shining Crystal#tt_b1::OnEnable")
    |> donpcevent("Shining Crystal#tt_y1::OnEnable")
  end

  defp ev_ontimer600000(ctx) do
    ctx
    |> donpcevent("Shining Crystal#tt_r1::OnDisable")
    |> donpcevent("Shining Crystal#tt_g1::OnDisable")
    |> donpcevent("Shining Crystal#tt_b1::OnDisable")
    |> donpcevent("Shining Crystal#tt_y1::OnDisable")
    |> donpcevent("Shining Crystal#tt_r2::OnEnable")
    |> donpcevent("Shining Crystal#tt_g2::OnEnable")
    |> donpcevent("Shining Crystal#tt_b2::OnEnable")
    |> donpcevent("Shining Crystal#tt_y2::OnEnable")
  end

  defp ev_ontimer1200000(ctx) do
    ctx
    |> donpcevent("Shining Crystal#tt_r2::OnDisable")
    |> donpcevent("Shining Crystal#tt_g2::OnDisable")
    |> donpcevent("Shining Crystal#tt_b2::OnDisable")
    |> donpcevent("Shining Crystal#tt_y2::OnDisable")
    |> donpcevent("Shining Crystal#tt_r3::OnEnable")
    |> donpcevent("Shining Crystal#tt_g3::OnEnable")
    |> donpcevent("Shining Crystal#tt_b3::OnEnable")
    |> donpcevent("Shining Crystal#tt_y3::OnEnable")
  end

  defp ev_ontimer1800000(ctx) do
    ctx
    |> donpcevent("Shining Crystal#tt_r3::OnDisable")
    |> donpcevent("Shining Crystal#tt_g3::OnDisable")
    |> donpcevent("Shining Crystal#tt_b3::OnDisable")
    |> donpcevent("Shining Crystal#tt_y3::OnDisable")
    |> donpcevent("Shining Crystal#tt_r4::OnEnable")
    |> donpcevent("Shining Crystal#tt_g4::OnEnable")
    |> donpcevent("Shining Crystal#tt_b4::OnEnable")
    |> donpcevent("Shining Crystal#tt_y4::OnEnable")
  end

  defp ev_ontimer2400000(ctx) do
    ctx
    |> donpcevent("Shining Crystal#tt_r4::OnDisable")
    |> donpcevent("Shining Crystal#tt_g4::OnDisable")
    |> donpcevent("Shining Crystal#tt_b4::OnDisable")
    |> donpcevent("Shining Crystal#tt_y4::OnDisable")
    |> donpcevent("#Charm Stone Admintt01::OnEnable")
  end
end
