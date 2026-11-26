defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.ThanatosSeal do
  @moduledoc """
  Starts the Thanatos summoning sequence when the seal is touched.

  ## Behavior

  - Announces Thanatos's return on a timer before triggering the summon.

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
        y: 228,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#thanatos_seal",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer1000", ctx) do
    ev_ontimer1000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer4000", ctx) do
    ev_ontimer4000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer7000", ctx) do
    ev_ontimer7000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer10000", ctx) do
    ev_ontimer10000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer13000", ctx) do
    ev_ontimer13000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer16000", ctx) do
    ev_ontimer16000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ev_onenable(ctx) do
    enablenpc(ctx, "#thanatos_seal")
  end

  defp ev_ondisable(ctx) do
    disablenpc(ctx, "#thanatos_seal")
  end

  defp ev_ontouch(ctx) do
    if get_server_temp_var(ctx, "thana_summon2", 0) == 4 do
      ctx
      |> initnpctimer()
      |> donpcevent("Memory Seal#tt5::OnEnable")
      |> disablenpc("#thanatos_seal")
    else
      ctx
    end
  end

  defp ev_ontimer1000(ctx) do
    mapannounce(ctx, "thana_boss", "Thanatos : RAWWWWWWWWWWWWWWWWR!", 1, "0xff0000")
  end

  defp ev_ontimer4000(ctx) do
    mapannounce(
      ctx,
      "thana_boss",
      "Thanatos : ... crashed... broken... spread... and come back as tears...",
      1,
      "0xff0000"
    )
  end

  defp ev_ontimer7000(ctx) do
    mapannounce(
      ctx,
      "thana_boss",
      "Thanatos : I live again to fulfill my ambition!",
      1,
      "0xff0000"
    )
  end

  defp ev_ontimer10000(ctx) do
    mapannounce(
      ctx,
      "thana_boss",
      "Thanatos : ... gives off a strong bloody scent... soaked in sorrow...",
      1,
      "0xff0000"
    )
  end

  defp ev_ontimer13000(ctx) do
    mapannounce(
      ctx,
      "thana_boss",
      "Thanatos : I will remove all people who invade this continent again!",
      1,
      "0xff0000"
    )
  end

  defp ev_ontimer16000(ctx) do
    ctx
    |> mapannounce(
      "thana_boss",
      "Thanatos : Come, be the first to fall before my might!",
      1,
      "0xff0000"
    )
    |> donpcevent("Memory Seal#tt5::OnDisable")
    |> donpcevent("#sommon_thanatos::OnEnable")
    |> set_server_temp_var("thana_summon2", 5)
    |> stopnpctimer()
  end
end
