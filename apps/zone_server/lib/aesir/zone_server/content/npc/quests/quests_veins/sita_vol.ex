defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.SitaVol do
  @moduledoc """
  A hidden trigger reveals signs of activity beneath the volcano.

  ## Behavior

  - At the relevant quest stage, approaching the site advances the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thor_camp",
        x: 172,
        y: 132,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sita_vol",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_vol, 0) == 21 do
      ctx
      |> mes("^3355FFThere's a stream of")
      |> mes("magma running down")
      |> mes("through a path under")
      |> mes("the barbed wires.^000000")
      |> next()
      |> mes("^3355FFYou can hear the faint")
      |> mes("sound of hammering, as if")
      |> mes("iron was being manufactured")
      |> mes("from deep underground.^000000")
      |> set_char_var(:aru_vol, 22)
      |> close()
    else
      ctx
    end
  end
end
