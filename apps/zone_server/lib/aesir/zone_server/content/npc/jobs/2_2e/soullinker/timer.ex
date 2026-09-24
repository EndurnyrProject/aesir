defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.Timer do
  @moduledoc """
  Times the Soul Linker job change ceremony and clears the ceremony map when time runs out.

  ## Behavior

  - Starts when a candidate enters the ceremony and stops when the job change completes.
  - Frees the ceremony early if the ceremony map is empty at the two-minute mark.
  - Warps everyone on the ceremony map back to Morocc just after three minutes and frees the
    ceremony.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_soul",
        x: 1,
        y: 5,
        dir: 0,
        sprite: 111,
        name: "Timer",
        scope: :shared,
        unique_name: "Timer#link3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnDisable", ctx), do: stop_ceremony(ctx)
  def on_event("OnTimer60000", ctx), do: ctx

  def on_event("OnTimer120000", ctx) do
    if getmapusers(ctx, "job_soul") == 0 do
      stop_ceremony(ctx)
    else
      ctx
    end
  end

  def on_event("OnTimer180000", ctx), do: ctx
  def on_event("OnTimer181000", ctx), do: ctx
  def on_event("OnTimer182000", ctx), do: mapwarp(ctx, "job_soul", "morocc", 157, 47)

  def on_event("OnTimer183000", ctx) do
    ctx
    |> mapwarp("job_soul", "morocc", 157, 47)
    |> set_npc_var_of("SoulLinkerTest", "Kid#link1", 0)
    |> stopnpctimer()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp stop_ceremony(ctx) do
    ctx
    |> stopnpctimer()
    |> set_npc_var_of("SoulLinkerTest", "Kid#link1", 0)
  end
end
