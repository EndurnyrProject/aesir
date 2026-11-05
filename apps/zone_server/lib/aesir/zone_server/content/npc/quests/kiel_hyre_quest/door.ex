defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Door do
  @moduledoc """
  The cottage door reveals a directional note when first unlocked.

  ## Behavior

  - Uses Elly’s key at the relevant quest stage, advances the quest, and admits the player.
  - Offers entry once the door has been opened.

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
        map: "yuno_fild02",
        x: 75,
        y: 218,
        dir: 0,
        sprite: 111,
        name: "Door",
        scope: :shared,
        unique_name: "Door#kh2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest < 16 -> ctx |> describe_lock() |> close()
      quest == 16 -> unlock_door(ctx)
      true -> enter_cottage(ctx)
    end
  end

  defp describe_lock(ctx) do
    ctx
    |> mes("^3355FFThis door is locked.")
    |> mes("If someone inside won't")
    |> mes("open it for you, then you'll")
    |> mes("need the right key to unlock it.")
  end

  defp unlock_door(ctx) do
    {ctx, choice} = ctx |> describe_lock() |> next() |> select(["Unlock", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou unlock the door with the")
        |> mes("key that Elly gave you, and")
        |> mes("as you push it open, a folded")
        |> mes("note dropped from top of the")
        |> mes("door. The following words")
        |> mes("are written on this crude note.")
        |> next()
        |> mes("6 Forward,")
        |> mes("3 Left,")
        |> mes("3 Forward,")
        |> mes("4 Left")
        |> close()
        |> set_char_var(:KielHyreQuest, 18)
        |> warp("kh_vila", 188, 18)

      2 ->
        ctx |> mes("......") |> mes(".........") |> mes("............") |> close()

      _ ->
        ctx
    end
  end

  defp enter_cottage(ctx) do
    {ctx, choice} =
      ctx |> mes("^3355FFThe door is open.^000000") |> next() |> select(["Enter", "Cancel"])

    case choice do
      1 -> warp(ctx, "kh_vila", 188, 18)
      2 -> close(ctx)
      _ -> ctx
    end
  end
end
