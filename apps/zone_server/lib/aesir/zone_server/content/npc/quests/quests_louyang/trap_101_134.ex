defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Trap101134 do
  @moduledoc """
  A castle guard catches intruders during the poison quest.

  ## Behavior

  - Sends the player outside when the poison quest is at stage 12 or 16.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in01",
        x: 101,
        y: 134,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#lou_in3",
        trigger: {20, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    catch_intruder(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    catch_intruder(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp catch_intruder(ctx) do
    if get_char_var(ctx, :ch_poison, 0) in [12, 16] do
      ctx
      |> mes("[Soldier]")
      |> mes("Huh...?")
      |> mes("Is somebody there?")
      |> next()
      |> mes("^3355FFYou escaped from the soldier's suspicious gaze.^000000")
      |> close2()
      |> warp("louyang", 218, 246)
    else
      ctx
    end
  end
end
