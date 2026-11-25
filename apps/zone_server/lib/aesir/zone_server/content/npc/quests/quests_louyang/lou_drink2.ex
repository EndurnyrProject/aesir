defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.LouDrink2 do
  @moduledoc """
  A crack provides an escape from the castle.

  ## Behavior

  - Sends the player outside at poison quest stages 12 and 13.

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
        x: 118,
        y: 167,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #lou_drink2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_poison, 0) in [12, 13] do
      ctx
      |> mes("^3355FFYou squeeze through the crack as quickly as you can.^000000")
      |> close2()
      |> warp("louyang", 217, 278)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
