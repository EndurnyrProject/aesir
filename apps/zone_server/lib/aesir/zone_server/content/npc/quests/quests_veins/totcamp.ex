defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Totcamp do
  @moduledoc """
  Sends visitors to the appropriate camp entrance.

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
        map: "thor_v02",
        x: 143,
        y: 78,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#totcamp",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
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
    if get_char_var(ctx, :rachel_camel, 0) < 24 do
      warp(ctx, "que_thor", 65, 55)
    else
      warp(ctx, "que_thor", 182, 55)
    end
  end
end
