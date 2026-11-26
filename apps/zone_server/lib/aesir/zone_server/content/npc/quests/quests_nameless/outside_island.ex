defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OutsideIsland do
  @moduledoc """
  The island entrance reveals traces of a mysterious creature.

  ## Behavior

  - Displays a clue when the player reaches the relevant quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nameless_i",
        x: 212,
        y: 184,
        dir: 0,
        sprite: -1,
        name: "Outside Island",
        scope: :shared,
        unique_name: "Outside Island#Aru",
        trigger: {2, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 17 do
      describe_island(ctx)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_island(ctx) do
    ctx
    |> mes("^3355FFThe village is totally")
    |> mes("silent, as if all life had")
    |> mes("abandoned it. You look")
    |> mes("around and see that something")
    |> mes("was here a few hours ago, but")
    |> mes("it's somewhere else now.^000000")
    |> next()
    |> mes("^3355FFWhatever it was,")
    |> mes("it definitely wasn't")
    |> mes("human. What kind of")
    |> mes("creature could it be?^000000")
    |> close()
  end
end
