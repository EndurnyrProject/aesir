defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.AlliedManager do
  @moduledoc """
  The GM manager of the allied attack reset, whose password comes from the GM NPC script
  outside the enabled graphs.

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
        map: "moc_fild22b",
        x: 370,
        y: 370,
        dir: 3,
        sprite: 100,
        name: "Allied Manager",
        scope: :shared,
        unique_name: "Allied Manager#gm"
      }
    ]

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Todo

  @head_of_the_alliance "Head of the Alliance#moo"

  @doc false
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("[Manager]")
      |> mes("Please enter the password.")
      |> next()

    case Todo.call!(:callfunc, ["F_GM_NPC", 8028, 0, 0, 9000]) do
      -2 -> incorrect_password(ctx)
      -1 -> zero_password(ctx)
      0 -> nevermind(ctx)
      _entered -> manager_menu(ctx)
    end
  end

  defp incorrect_password(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes("Incorrect password.")
    |> close()
  end

  defp zero_password(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes("Please enter a password other then 0.")
    |> close()
  end

  defp nevermind(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes("Nevermind then.")
    |> close()
  end

  defp manager_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Manager]")
      |> mes("What would you like to do?")
      |> next()
      |> select(["Reset the Allied Attacks.", "Nothing."])

    case choice do
      1 -> reset_attacks(ctx)
      2 -> nevermind(ctx)
      _ -> ctx
    end
  end

  defp reset_attacks(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes("Resetting the allied attacks.")
    |> set_server_temp_var("ep13_test", 2)
    |> disablenpc(@head_of_the_alliance)
    |> close()
  end
end
