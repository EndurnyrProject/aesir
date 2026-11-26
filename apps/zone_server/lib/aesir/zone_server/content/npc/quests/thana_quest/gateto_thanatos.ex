defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.GatetoThanatos do
  @moduledoc """
  Controls the gate to the Thanatos chamber.

  ## Behavior

  - Opens the chamber gate and displays seal effects.

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
        map: "tha_t12",
        x: 130,
        y: 52,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#gateto_thanatos",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnOn2", ctx), do: ev_onon2(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnTimer6000", ctx), do: ev_ontimer6000(ctx)
  def on_event("OnTimer1000", ctx), do: ev_ontimer1000(ctx)
  def on_event("OnTimer5000", ctx), do: ev_ontimer5000(ctx)
  def on_event("OnTimer3000", ctx), do: ev_ontimer3000(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  defp ev_oninit(ctx) do
    disablenpc(ctx, "#gateto_thanatos")
  end

  defp ev_onenable(ctx) do
    ctx |> enablenpc("#gateto_thanatos") |> ev_onon2()
  end

  defp ev_onon2(ctx) do
    initnpctimer(ctx)
  end

  defp ev_ontouch(ctx) do
    ctx |> set_local(:touch, 1) |> ev_ontimer6000()
  end

  defp ev_ontimer6000(ctx) do
    cond do
      get_server_temp_var(ctx, "thana_summon", 0) == 0 or
          get_server_temp_var(ctx, "thana_summon", 0) == 6 ->
        ctx |> disablenpc("#gateto_thanatos") |> stopnpctimer()

      get_server_temp_var(ctx, "thana_summon", 0) == 5 ->
        if Rathena.truthy?(get_local(ctx, :touch, 0)) do
          warp(ctx, "thana_boss", 136, 116)
        else
          donpcevent(ctx, "#gateto_thanatos::OnOn2")
        end

      true ->
        ctx
    end
  end

  defp ev_ontimer1000(ctx) do
    ev_ontimer5000(ctx)
  end

  defp ev_ontimer5000(ctx) do
    ctx |> set_local(:pillar, 1) |> ev_ontimer3000()
  end

  defp ev_ontimer3000(ctx) do
    ctx =
      ctx
      |> specialeffect(:beginspell7, :area, "#tteffect05")
      |> specialeffect(:beginspell3, :area, "#tteffect04")
      |> specialeffect(:beginspell2, :area, "#tteffect03")
      |> specialeffect(:beginspell4, :area, "#tteffect02")
      |> specialeffect(:beginspell5, :area, "#tteffect01")

    if Rathena.truthy?(get_local(ctx, :pillar, 0)) do
      specialeffect(ctx, :mappillar2)
    else
      ctx
    end
  end
end
