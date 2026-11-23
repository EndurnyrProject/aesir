defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.SkullStone do
  @moduledoc """
  The Skull Stone concludes a treasure hunt with a random reward.

  ## Behavior

  - Completes the quest and gives a random banana reward when the skull key is used.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tur_dun01",
        x: 160,
        y: 81,
        dir: 4,
        sprite: 111,
        name: "Skull Stone",
        scope: :shared,
        unique_name: "Skull Stone#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :TURTLE, 0) == 2 do
      ctx =
        ctx
        |> mes("^3355FFUnder the stone^000000")
        |> mes("^3355FFis a tiny key hole^000000")
        |> mes("^3355FFwith a skull mark.^000000")
        |> mes("^3355FFYou used the Skull key^000000")
        |> mes("^3355FFin that key hole.^000000")
        |> next()
        |> mes("^3355FF*Click! Click!*^000000")
        |> next()
        |> mes("^3355FFSuddenly, the top of^000000")
        |> mes("^3355FFthe stone opened and^000000")
        |> mes("^3355FFsome items popped out!!^000000")
        |> next()

      ctx =
        ctx
        |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 65536))
        |> set_char_var(:TURTLE, 0)
        |> completequest(11030)

      reward = Enum.random(1..3)

      case reward do
        1 ->
          ctx
          |> give_item(532, 5)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FF5 Banana Juice^000000")
          |> close()

        2 ->
          ctx
          |> give_item(513, 5)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FF5 Banana^000000")
          |> close()

        3 ->
          ctx
          |> give_item(513, 5)
          |> give_item(532, 5)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FF5 Banana and^000000")
          |> mes("^3355FF5 Banana Juice^000000")
          |> close()

        _ ->
          describe(ctx)
      end
    else
      describe(ctx)
    end
  end

  defp describe(ctx) do
    ctx
    |> mes("^3355FFIt is a frightening^000000")
    |> mes("^3355FFstone tomb with a^000000")
    |> mes("^3355FFhorrible skull on it.^000000")
    |> close()
  end
end
