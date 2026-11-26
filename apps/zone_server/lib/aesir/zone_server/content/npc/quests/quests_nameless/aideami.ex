defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Aideami do
  @moduledoc """
  A low wall provides access to the monastery.

  ## Behavior

  - Quest progress determines whether the player can climb the wall.

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
        map: "nameless_n",
        x: 145,
        y: 162,
        dir: 0,
        sprite: 139,
        name: "AideAmi",
        scope: :shared,
        unique_name: "AideAmi#Aru",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 26 do
      {ctx, choice} =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes(
          "There is a low wall here against the other wall, if I climb it I could reach the resting place of Tristan III..."
        )
        |> next()
        |> select(["Stay here", "Climb the wall"])

      case choice do
        1 -> warp(ctx, "nameless_n", 158, 169)
        2 -> warp(ctx, "abbey01", 51, 15)
        _ -> ctx
      end
    else
      warp(ctx, "nameless_n", 158, 169)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx
end
