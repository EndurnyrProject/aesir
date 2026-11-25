defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.LouPath do
  @moduledoc """
  A crack provides a secret entrance to the castle.

  ## Behavior

  - Allows entry at poison quest stages 12 and 16.

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
        map: "louyang",
        x: 217,
        y: 278,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #lou_path"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_poison, 0) in [12, 16] do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What's this?")
      |> mes("A crack in the wall?")
      |> next()
      |> mes(
        "^3355FFYou jump to the stone wall and peep into the crack. It looks big enough for someone to squeeze through.^000000"
      )
      |> next()
      |> mes("^3355FFYou move through the crack as quickly as you can.^000000")
      |> close2()
      |> warp("lou_in01", 119, 167)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
