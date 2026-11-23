defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.TurtlePillar do
  @moduledoc """
  The Turtle Pillar concludes a treasure hunt with a random reward.

  ## Behavior

  - Completes the quest and gives one randomly selected item when the pillar key is used.

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
        map: "tur_dun02",
        x: 49,
        y: 158,
        dir: 4,
        sprite: 111,
        name: "Turtle Pillar",
        scope: :shared,
        unique_name: "Turtle Pillar#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :TURTLE, 0) == 8 do
      ctx =
        ctx
        |> mes("^3355FFAt the base of the pillar^000000")
        |> mes("^3355FFis a tiny key hole with^000000")
        |> mes("^3355FFa turtle shaped mark.^000000")
        |> mes("^3355FFYou used the")
        |> mes("Turtle Pillar key")
        |> mes("in that key hole.^000000")
        |> next()
        |> mes("^3355FF*Click! Crack!*^000000")
        |> next()
        |> mes("^3355FFAt the base of the pillar,^000000")
        |> mes("^3355FFa little door appears, and^000000")
        |> mes("^3355FFfrom that door an engraved^000000")
        |> mes("^3355FFstone bead rolls out.^000000")
        |> next()
        |> mes("[Turtle Stone Bead]")
        |> mes("This turtle pillar is made of the strongest material on this island.")
        |> next()
        |> mes("[Turtle Stone Bead]")
        |> mes(
          "Cutting it is impossible for even someone with legendary skills. Even if I managed to cut it, all of Turtle Island would collapse upon me."
        )
        |> next()
        |> mes("[Turtle Stone Bead]")
        |> mes(
          "I've developed my mental skills, and trained using materials on this island. Sharpening my mind, I now know that I can cut this pillar in two."
        )
        |> next()
        |> mes("[Turtle Stone Bead]")
        |> mes("Can this be the pinnacle of swordsmanship? Of the sword arts?")
        |> next()
        |> mes("[Turtle Stone Bead]")
        |> mes("For this final accomplishment, I leave behind an offering.")
        |> next()
        |> mes("[Turtle Stone Bead]")
        |> mes(
          "I intend to offer my gratitude to the blood of the monsters I have killed, and the materials I have used in my training."
        )
        |> next()
        |> mes("^3355FFThere are many items^000000")
        |> mes("^3355FFunder the pillar...^000000")

      ctx =
        ctx
        |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 65536))
        |> set_char_var(:TURTLE, 0)
        |> completequest(11034)

      reward = Enum.random(1..10)

      case reward do
        1 ->
          ctx
          |> give_item(702, 1)
          |> mes("^3355FFYou've gained ^000000")
          |> mes("^3355FFAnimal Gore.^000000")
          |> close()

        2 ->
          ctx
          |> give_item(716, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Red Gemstone.^000000")
          |> close()

        3 ->
          ctx
          |> give_item(734, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Red Frame^000000")
          |> close()

        4 ->
          ctx
          |> give_item(10019, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFRed Scarf.^000000")
          |> close()

        5 ->
          ctx
          |> give_item(725, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Sardonyx.^000000")
          |> close()

        6 ->
          ctx
          |> give_item(716, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Red Gemstone.^000000")
          |> close()

        7 ->
          ctx
          |> give_item(716, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Red Gemstone.^000000")
          |> close()

        8 ->
          ctx
          |> give_item(716, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Red Gemstone.^000000")
          |> close()

        9 ->
          ctx
          |> give_item(716, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Red Gemstone.^000000")
          |> close()

        10 ->
          ctx
          |> give_item(725, 1)
          |> mes("^3355FFYou've gained^000000")
          |> mes("^3355FFa Sardonyx.^000000")
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
    |> mes("^3355FFThis Turtle Pillar^000000")
    |> mes("^3355FFis just one of^000000")
    |> mes("^3355FFmany pillars.^000000")
    |> next()
    |> mes("^3355FFOr is it...?^000000")
    |> close()
  end
end
