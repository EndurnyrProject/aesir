defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Boatman do
  @moduledoc """
  A boatman ferries adventurers between Hugel and the Odin Shrine.

  ## Behavior

  - Offers passage to the destination and preserves quest progression.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hugel",
        x: 209,
        y: 109,
        dir: 2,
        sprite: 709,
        name: "Boatman",
        scope: :shared,
        unique_name: "Boatman#hugel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boatman]")
      |> mes("Ah, hello~")
      |> mes("Would you like to sail")
      |> mes("to the Odin Shrine? The")
      |> mes("fare for 1 passenger is")
      |> mes("800 zeny. Shall we board?")
      |> next()
      |> select(["No, thanks.", "Sure!"])

    case choice do
      1 -> decline(ctx)
      2 -> board(ctx)
      _ -> ctx
    end
  end

  defp decline(ctx) do
    ctx
    |> mes("[Boatman]")
    |> mes("Ah, alright.")
    |> mes("If you change your")
    |> mes("mind, I invite you")
    |> mes("to return and just")
    |> mes("let me know.")
    |> close()
  end

  defp board(ctx) do
    if zeny(ctx) < 800 do
      insufficient_fare(ctx)
    else
      sail(ctx)
    end
  end

  defp insufficient_fare(ctx) do
    ctx
    |> mes("[Boatman]")
    |> mes("Hm? You don't have enough")
    |> mes("money to pay the fare. Well,")
    |> mes("just come back when you do")
    |> mes("have the zeny, and then I'll")
    |> mes("take you to the Odin Shrine.")
    |> close()
  end

  defp sail(ctx) do
    ctx =
      ctx
      |> mes("[Boatman]")
      |> mes("Alright then,")
      |> mes("climb aboard!")
      |> mes("We'll arrive near")
      |> mes("the Odin Shrine soon~")
      |> close()
      |> pay_zeny(800)

    ctx =
      case get_char_var(ctx, :hg_odin, 0) do
        stage when stage in [2, 4, 12, 14] -> set_char_var(ctx, :hg_odin, stage + 1)
        _ -> ctx
      end

    warp(ctx, "odin_tem01", 100, 146)
  end
end
