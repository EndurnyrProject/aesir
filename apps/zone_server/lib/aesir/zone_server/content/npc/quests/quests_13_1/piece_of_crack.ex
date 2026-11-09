defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.PieceOfCrack do
  @moduledoc """
  A crack in the Schwarzwald ruins that sets the player's Cat trading points to a value
  between 1 and 3000.

  ## Behavior

  - Runs the GM NPC gate and asks for a number on the 1 to 3000 range.
  - Stores the number in `ep13_yong1`, or rejects it with the range it accepts.
  - `F_GM_NPC` comes from `npc/other/gm_npcs.txt`, which is outside the enabled graphs, so the
    gate is still a `todo` stub.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 80,
        y: 171,
        dir: 0,
        sprite: 406,
        name: "Piece of crack",
        scope: :shared,
        unique_name: "Piece of crack#sec"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @cat_trading_points 3000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, points} =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("1~3000")
      |> input(:int)

    ctx = next(ctx)

    if points < 1 or points > @cat_trading_points do
      ctx
      |> mes("Cat trading Point adjust")
      |> mes("You can enter the number between 1~3000.")
      |> close()
    else
      ctx
      |> set_char_var(:ep13_yong1, points)
      |> close()
    end
  end
end
