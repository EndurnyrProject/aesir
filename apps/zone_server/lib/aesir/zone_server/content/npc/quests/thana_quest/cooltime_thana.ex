defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.CooltimeThana do
  @moduledoc """
  Manages the Thanatos seal countdown and cooldown.

  ## Behavior

  - Warns and ejects players before resetting the seals.

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
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#cooltime_thana"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnStop", ctx), do: ev_onstop(ctx)
  def on_event("OnTimer3000", ctx), do: ev_ontimer3000(ctx)
  def on_event("OnTimer6000", ctx), do: ev_ontimer6000(ctx)
  def on_event("OnTimer16000", ctx), do: ev_ontimer16000(ctx)
  def on_event("OnTimer26000", ctx), do: ev_ontimer26000(ctx)
  def on_event("OnTimer31000", ctx), do: ev_ontimer31000(ctx)
  def on_event("OnTimer32000", ctx), do: ev_ontimer32000(ctx)
  def on_event("OnTimer33000", ctx), do: ev_ontimer33000(ctx)
  def on_event("OnTimer34000", ctx), do: ev_ontimer34000(ctx)
  def on_event("OnTimer35000", ctx), do: ev_ontimer35000(ctx)
  def on_event("OnTimer36000", ctx), do: ev_ontimer36000(ctx)
  def on_event("OnTimer37000", ctx), do: ev_ontimer37000(ctx)
  def on_event("OnTimer7200000", ctx), do: ev_ontimer7200000(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  defp ev_oninit(ctx) do
    ctx |> set_server_temp_var("thana_summon", 0) |> set_server_temp_var("thana_summon2", 0)
  end

  defp ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  defp ev_onstop(ctx) do
    stopnpctimer(ctx)
  end

  defp ev_ontimer3000(ctx) do
    mapannounce(ctx, "thana_boss", "Warning!!", 1, "0x00ff00")
  end

  defp ev_ontimer6000(ctx) do
    mapannounce(ctx, "thana_boss", "The seal will re-activate in 30 seconds.", 1, "0x00ff00")
  end

  defp ev_ontimer16000(ctx) do
    mapannounce(ctx, "thana_boss", "20 seconds left...", 1, "0x00ff00")
  end

  defp ev_ontimer26000(ctx) do
    mapannounce(ctx, "thana_boss", "10 seconds left...", 1, "0x00ff00")
  end

  defp ev_ontimer31000(ctx) do
    mapannounce(ctx, "thana_boss", "5 seconds.", 1, "0x00ff00")
  end

  defp ev_ontimer32000(ctx) do
    mapannounce(ctx, "thana_boss", "4 seconds.", 1, "0x00ff00")
  end

  defp ev_ontimer33000(ctx) do
    mapannounce(ctx, "thana_boss", "3 seconds.", 1, "0x00ff00")
  end

  defp ev_ontimer34000(ctx) do
    mapannounce(ctx, "thana_boss", "2 seconds.", 1, "0x00ff00")
  end

  defp ev_ontimer35000(ctx) do
    mapannounce(ctx, "thana_boss", "Time's up!", 1, "0xff0000")
  end

  defp ev_ontimer36000(ctx) do
    ev_ontimer37000(ctx)
  end

  defp ev_ontimer37000(ctx) do
    mapwarp(ctx, "thana_boss", "tha_t12", 130, 52)
  end

  defp ev_ontimer7200000(ctx) do
    ctx
    |> set_server_temp_var("thana_summon", 0)
    |> set_server_temp_var("thana_summon2", 0)
    |> donpcevent("Memory Seal#tt1::OnEnable")
    |> donpcevent("Memory Seal#tt2::OnEnable")
    |> donpcevent("Memory Seal#tt3::OnEnable")
    |> donpcevent("Memory Seal#tt4::OnEnable")
    |> donpcevent("#thanatos_seal::OnEnable")
    |> stopnpctimer()
  end
end
