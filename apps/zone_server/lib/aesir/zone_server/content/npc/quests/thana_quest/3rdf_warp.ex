defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.M3rdfWarp do
  @moduledoc """
  Controls the timed portal to the third floor.

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
        map: "tha_t02",
        x: 227,
        y: 163,
        dir: 0,
        sprite: 45,
        name: "3rdf_warp",
        scope: :shared,
        unique_name: "3rdf_warp#tt",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer30000", ctx) do
    ev_ontimer30000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ev_oninit(ctx) do
    disablenpc(ctx, "3rdf_warp#tt")
  end

  defp ev_ontouch(ctx) do
    if get_char_var(ctx, :thana_tower, 0) == 0 do
      warp(ctx, "tha_t02", 227, 158)
    else
      warp(ctx, "tha_t03", 219, 159)
    end
  end

  defp ev_onenable(ctx) do
    ctx |> enablenpc("3rdf_warp#tt") |> initnpctimer()
  end

  defp ev_ontimer30000(ctx) do
    ctx |> stopnpctimer() |> disablenpc("3rdf_warp#tt")
  end
end
