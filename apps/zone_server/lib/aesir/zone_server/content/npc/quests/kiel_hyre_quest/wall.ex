defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Wall do
  @moduledoc """
  The cottage wall conceals a passage unlocked through quest progress.

  ## Behavior

  - Offers entry to the secret path once the wall has opened.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_vila",
        x: 191,
        y: 14,
        dir: 0,
        sprite: 139,
        name: "Wall",
        scope: :shared,
        unique_name: "Wall#kh",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) < 28 do
      ctx
      |> mes("^3355FFIt's just a wall.")
      |> mes("It's not particularly")
      |> mes("standing in your way.^000000")
      |> close()
    else
      enter_passage(ctx)
    end
  end

  defp enter_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThe wall is now")
      |> mes("open, revealing")
      |> mes("a secret path.^000000")
      |> next()
      |> select(["Enter", "Cancel"])

    case choice do
      1 -> warp(ctx, "kh_vila", 17, 177)
      2 -> close(ctx)
      _ -> ctx
    end
  end
end
