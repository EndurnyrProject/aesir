defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Soldier91151 do
  @moduledoc """
  A sleepy soldier guards the castle.

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
        x: 91,
        y: 151,
        dir: 4,
        sprite: 825,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#bailong2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_poison, 0) == 12 or get_char_var(ctx, :ch_poison, 0) == 16 do
      ctx
      |> mes("[Soldier]")
      |> mes("Huh...?")
      |> mes("Is somebody there? ")
      |> next()
      |> mes("^3355FFYou ran away")
      |> mes("as quickly")
      |> mes("as you could.^000000")
      |> close2()
      |> warp("louyang", 218, 246)
    else
      {ctx, _} =
        ctx
        |> mes("[Soldier]")
        |> mes(".....z...Z....z...")
        |> next()
        |> select(["Hey, wake up!"])

      ctx
      |> mes("[Soldier]")
      |> mes("Yeeeesss...Sir!")
      |> mes("I was not dozing off~ seerious...ly...")
      |> next()
      |> mes("[Soldier]")
      |> mes("...")
      |> next()
      |> mes("[Soldier]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Soldier]")
      |> mes(".....z...Z....z...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
