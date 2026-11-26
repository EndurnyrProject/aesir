defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.MemorySeal141235 do
  @moduledoc """
  The final memory seal appears during the Thanatos encounter.

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
        y: 235,
        dir: 3,
        sprite: 1708,
        name: "Memory Seal",
        scope: :shared,
        unique_name: "Memory Seal#tt5"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  defp ev_oninit(ctx) do
    disablenpc(ctx, "Memory Seal#tt5")
  end

  defp ev_onenable(ctx) do
    enablenpc(ctx, "Memory Seal#tt5")
  end

  defp ev_ondisable(ctx) do
    ctx |> disablenpc("Memory Seal#tt5") |> specialeffect(:icecrash)
  end
end
