defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Soldier99144 do
  @moduledoc """
  A castle soldier welcomes visitors.

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
        x: 99,
        y: 144,
        dir: 4,
        sprite: 825,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#bailong4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_poison, 0) == 12 or get_char_var(ctx, :ch_poison, 0) == 16 do
      ctx
      |> mes("[Soldier]")
      |> mes("Who goes there?!")
      |> next()
      |> mes("^3355FFYou ran away")
      |> mes("as quickly")
      |> mes("as you could.^000000")
      |> close2()
      |> warp("louyang", 218, 246)
    else
      ctx
      |> mes("[Soldier]")
      |> mes("Ah, don't bother")
      |> mes("to listen to this")
      |> mes("guy beside of me.")
      |> next()
      |> mes("[Soldier]")
      |> mes("I hope you have a good time while you're staying here in Luoyang!")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
