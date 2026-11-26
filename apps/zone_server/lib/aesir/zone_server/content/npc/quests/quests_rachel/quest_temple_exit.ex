defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.QuestTempleExit do
  @moduledoc """
  A locked gate provides an escape from the sanctuary.

  ## Behavior

  - Opens when pushed or kicked at the appropriate quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_rachel",
        x: 169,
        y: 18,
        dir: 0,
        sprite: 45,
        name: "Quest Temple Exit",
        scope: :shared,
        unique_name: "Quest Temple Exit#ra_tem",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThe gate is closed.^000000")
      |> next()
      |> select(["Push Gate", "Examine Gate", "Kick Gate", "Smash Gate with Weapon"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou push the gate")
        |> mes("with all of your might...")
        |> try_gate(:push)

      2 ->
        ctx
        |> mes("^3355FFThere's some strange")
        |> mes("machinery installed on")
        |> mes("the gate, and a slot where")
        |> mes("it looks you you can insert")
        |> mes("a card or permit. The lights")
        |> mes("are on, so it must be working.^000000")
        |> close()

      3 ->
        ctx
        |> mes("^3355FFYou angrily kick the gate...")
        |> try_gate(:kick)

      4 ->
        ctx
        |> mes("^3355FFWait! That's not")
        |> mes("a good idea. You can't")
        |> mes("smash down the gate to")
        |> mes("a holy place: heroes don't")
        |> mes("specialize in desecration.^000000")
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp try_gate(ctx, action) do
    if get_char_var(ctx, :ra_tem_q, 0) == 9 do
      ctx
      |> close2()
      |> set_char_var(:ra_tem_q, 10)
      |> warp("ra_temple", 119, 175)
    else
      ctx
      |> gate_closed(action)
      |> close()
    end
  end

  defp gate_closed(ctx, :push), do: mes(ctx, "But it won't even budge.^000000")

  defp gate_closed(ctx, :kick) do
    ctx
    |> mes("But no matter how much rage")
    |> mes("you put into your kick, the")
    |> mes("gate refuses to open for you.")
    |> mes("Oh, and your foot hurts too.^000000.")
  end
end
