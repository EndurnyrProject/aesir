defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Soldier102144 do
  @moduledoc """
  A castle soldier discusses a rumored scammer.

  ## Behavior

  - Expels players at certain stages of the poison quest.

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
        x: 102,
        y: 144,
        dir: 4,
        sprite: 825,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#bailong3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_poison, 0) == 12 or get_char_var(ctx, :ch_poison, 0) == 16 do
      ctx
      |> mes("[Soldier]")
      |> mes("Huh...?")
      |> mes("What was that?")
      |> next()
      |> mes("^3355FFYou escape the soldier's")
      |> mes("suspicious gaze as quickly")
      |> mes("as you can.^000000")
      |> close2()
      |> warp("louyang", 218, 246)
    else
      {ctx, _} =
        ctx
        |> mes("[Soldier]")
        |> mes("People have been")
        |> mes("saying that there's")
        |> mes("a scammer at the")
        |> mes("entrance of town...")
        |> next()
        |> select(["...?"])

      ctx
      |> mes("[Soldier]")
      |> mes("But I went there and I didn't")
      |> mes("find anyone suspicious. I swear, everything seemed completely normal!")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
