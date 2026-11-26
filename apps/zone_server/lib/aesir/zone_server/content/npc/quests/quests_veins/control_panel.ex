defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ControlPanel do
  @moduledoc """
  Records an inspection of the camp power system.

  ## Behavior

  - Advances the volcano investigation when the panel is inspected.

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
        x: 109,
        y: 167,
        dir: 3,
        sprite: 111,
        name: "Control Panel",
        scope: :shared,
        unique_name: "Control Panel#vol"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :aru_vol, 0) == 17 do
      ctx =
        ctx
        |> mes("^3355FFThis control panel")
        |> mes("controls the main power")
        |> mes("resources for the Thor")
        |> mes("Volcano camp, helping it")
        |> mes("run its operations smoothly")
        |> mes("under the ground.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("All these pipes with molten")
        |> mes("rock flowing through them...")
        |> mes("I guess their heat is what")
        |> mes("powers this camp. That's")
        |> mes("actually a smart idea~")
        |> next()
        |> mes("^3355FFThe control panel emits")
        |> mes("faint mechanical noises")
        |> mes("and seems to be running")
        |> mes("pretty smoothly. Everything")
        |> mes("looks to be in working order.")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("No problems here.")
      |> mes("I guess I can go")
      |> mes("back to that colonel.")
      |> changequest(2124, 2125)
      |> set_char_var(:aru_vol, 18)
      |> close()
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
