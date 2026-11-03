defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.M1stJobQuestReset do
  @moduledoc """
  GM helper that resets a character's progress in one of the first class tutorial quests.

  ## Behavior

  - Restricted to GMs through the shared GM NPC check.
  - Clears the chosen quest variable for Swordsman, Merchant, Archer (both parts), Acolyte,
    Thief or Mage, then confirms.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 17,
        y: 156,
        dir: 3,
        sprite: 726,
        name: "1st Job Quest Reset",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, quest} =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("[1st Job Quest]")
      |> mes("Which would you like to reset?")
      |> next()
      |> select(["Swordsman", "Merchant", "Archer", "Acolyte", "Thief", "Mage"])

    ctx =
      case quest do
        1 -> set_char_var(ctx, :tu_swordman, 0)
        2 -> set_char_var(ctx, :tu_merchant, 0)
        3 -> ctx |> set_char_var(:tu_archer01, 0) |> set_char_var(:tu_archer02, 0)
        4 -> set_char_var(ctx, :tu_acolyte01, 0)
        5 -> set_char_var(ctx, :tu_thief01, 0)
        6 -> set_char_var(ctx, :tu_magician01, 0)
        _ -> ctx
      end

    ctx
    |> mes("Completed.")
    |> close()
  end
end
