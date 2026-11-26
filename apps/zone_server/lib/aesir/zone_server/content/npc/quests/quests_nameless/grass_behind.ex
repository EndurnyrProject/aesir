defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.GrassBehind do
  @moduledoc """
  A patch of grass reveals a disturbing scent during the investigation.

  ## Behavior

  - Describes animal corpses when the player reaches the relevant quest stage.

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
        x: 129,
        y: 218,
        dir: 0,
        sprite: -1,
        name: "Grass Behind",
        scope: :shared,
        unique_name: "Grass Behind#Aru",
        trigger: {4, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 17 do
      ctx
      |> mes("^3355FFA strange scent strikes")
      |> mes("you as you enter this field of")
      |> mes("grass. A few ^32CD32animal corpses^3355FF")
      |> mes("are strewn around the ground.^000000")
      |> close()
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx
end
