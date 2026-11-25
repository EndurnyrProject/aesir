defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Soldier do
  @moduledoc """
  A castle soldier talks about Luoyang’s rumors.

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
        x: 111,
        y: 151,
        dir: 4,
        sprite: 825,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#bailong1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_poison, 0) == 12 or get_char_var(ctx, :ch_poison, 0) == 16 do
      ctx
      |> mes("[Soldier]")
      |> mes("Hey...")
      |> mes("There's something")
      |> mes("fishy about you...! ")
      |> next()
      |> mes("^3355FFYou escaped from the castle, far away from the suspicious guard...^000000")
      |> close2()
      |> warp("louyang", 218, 246)
    else
      ctx
      |> mes("[Soldier]")
      |> mes("^666666*Yawn*^000000 It's so boring here nowadays. Although, I hear that")
      |> mes("a long time ago, things were")
      |> mes("much different.")
      |> next()
      |> mes("[Soldier]")
      |> mes(
        "Supposedly, monsters used to intrude Luoyang all the time! Heh, but that's just a rumor. Still, there are a bunch of rumors going around that I'm curious about..."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
