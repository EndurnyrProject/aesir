defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.BukiVol do
  @moduledoc """
  Reveals the origin of the camp’s military supplies.

  ## Behavior

  - Advances the volcano investigation when the player approaches.

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
        x: 148,
        y: 310,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#buki_vol",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
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
    if get_char_var(ctx, :aru_vol, 0) == 22 do
      ctx =
        ctx
        |> mes("^3355FFPeople are carrying")
        |> mes("many heavy wooden boxes")
        |> mes("imprinted with the stamp")
        |> mes("of the Schwarzwald Republic.")
        |> mes("These must contain military")
        |> mes("supplies for the camp.^000000")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I should go back")
      |> mes("to Sahedi now.")
      |> changequest(2127, 2128)
      |> set_char_var(:aru_vol, 23)
      |> close()
    else
      ctx
    end
  end
end
