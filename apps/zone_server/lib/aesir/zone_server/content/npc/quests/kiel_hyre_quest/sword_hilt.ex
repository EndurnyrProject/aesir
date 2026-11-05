defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.SwordHilt do
  @moduledoc """
  The ornamental swords conceal a passage to the secret laboratory.

  ## Behavior

  - Uses poem progression to gate the sword-and-snake puzzle.
  - Opens the passage for the correct sword arrangement and permits later entry.

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
        x: 136,
        y: 68,
        dir: 0,
        sprite: 111,
        name: "Sword Hilt",
        scope: :shared,
        unique_name: "Sword Hilt#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    first_poem = get_char_var(ctx, :KHCottagePoem1, 0)
    second_poem = get_char_var(ctx, :KHCottagePoem2, 0)
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      first_poem < 3 or (second_poem < 2 and quest_stage < 30) ->
        ctx
        |> mes("^3355FFThere are four elaborately")
        |> mes("designed swords positioned")
        |> mes("next to four creepy looking")
        |> mes("snake sculptures.^000000")
        |> close()

      first_poem <= 4 or (second_poem <= 2 and quest_stage < 30) ->
        inspect_swords(ctx)

      (first_poem == 5 and second_poem == 3) or quest_stage >= 30 ->
        enter_passage(ctx)

      true ->
        ctx
    end
  end

  defp inspect_swords(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere are four elaborately")
      |> mes("designed swords positioned")
      |> mes("next to four creepy looking")
      |> mes("snake sculptures. Wait!")
      |> mes("Perhaps they're related to")
      |> mes("that poem you read earlier...")
      |> next()
      |> select(["No way!", "Of course!"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFImpossible...")
        |> mes("It must be some")
        |> mes("kind of coincidence...^000000")
        |> close()

      2 ->
        inspect_snakes(ctx)

      _ ->
        ctx
    end
  end

  defp inspect_snakes(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFOf course! And look!")
      |> mes("There's a hole on top")
      |> mes("of the head of each snake")
      |> mes("sculpture. These holes seem")
      |> mes("big enough to insert each of")
      |> mes("the ornamental swords nearby...^000000")
      |> next()
      |> select(["Ignore", "Insert Ornamental Swords"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFImposible...^000000")
        |> mes("^3355FFIt must be some^000000")
        |> mes("^3355FFkind of coincidence...^000000")
        |> close()

      2 ->
        insert_swords(ctx)

      _ ->
        ctx
    end
  end

  defp insert_swords(ctx) do
    if get_char_var(ctx, :KHCottagePoem1, 0) != 4 do
      ctx
      |> mes("^3355FFCan't... Pull out...")
      |> mes("Sword! It must be")
      |> mes("locked into place")
      |> mes("somehow, or sealed")
      |> mes("by some strange force!^000000")
      |> close()
    else
      arrange_swords(ctx)
    end
  end

  defp arrange_swords(ctx) do
    {ctx, snake} =
      ctx
      |> mes("^3355FFYou should probably")
      |> mes("try to insert each sword")
      |> mes("into the correct snake.")
      |> mes("First, please select the")
      |> mes("snake in which you will")
      |> mes("insert the first sword.^000000")
      |> next()
      |> select(["First Snake", "Second Snake", "Third Snake", "Fourth Snake"])

    ctx =
      if snake == 2 do
        set_local(ctx, :KHSwords, get_local(ctx, :KHSwords, 0) + 1)
      else
        ctx
      end

    {ctx, snake} =
      ctx
      |> next()
      |> mes("^3355FFNow, please choose")
      |> mes("the snake in which you")
      |> mes("will insert the second sword.^000000")
      |> next()
      |> select(["First Snake", "Second Snake", "Third Snake", "Fourth Snake"])

    ctx =
      if snake == 4 do
        set_local(ctx, :KHSwords, get_local(ctx, :KHSwords, 0) + 1)
      else
        ctx
      end

    {ctx, snake} =
      ctx
      |> next()
      |> mes("^3355FFNext, please select")
      |> mes("the snake in which you")
      |> mes("will insert the third sword.^000000")
      |> next()
      |> select(["First Snake", "Second Snake", "Third Snake", "Fourth Snake"])

    ctx =
      if snake == 1 do
        set_local(ctx, :KHSwords, get_local(ctx, :KHSwords, 0) + 1)
      else
        ctx
      end

    {ctx, snake} =
      ctx
      |> next()
      |> mes("^3355FFLastly, please select")
      |> mes("the snake in which you")
      |> mes("will insert the fourth sword.^000000")
      |> next()
      |> select(["First Snake", "Second Snake", "Third Snake", "Fourth Snake"])

    ctx =
      if snake == 3 do
        set_local(ctx, :KHSwords, get_local(ctx, :KHSwords, 0) + 1)
      else
        ctx
      end

    if get_local(ctx, :KHSwords, 0) == 4 do
      ctx
      |> mes("^3355FFYour ears are suddenly")
      |> mes("filled with a low buzzing")
      |> mes("noise, and your mind")
      |> mes("and body feel as if they")
      |> mes("are being swept away...^000000")
      |> set_char_var(:KHCottagePoem1, 5)
      |> set_char_var(:KHCottagePoem2, 3)
      |> close()
      |> warp("kh_vila", 178, 72)
    else
      ctx
      |> mes("^3355FFNothing happened...")
      |> mes("You probably didn't")
      |> mes("insert the swords into")
      |> mes("the correct snakes. For now,")
      |> mes("you should return the swords,")
      |> mes("and then try this again later.^000000")
      |> close()
    end
  end

  defp enter_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFHere is a hidden")
      |> mes("path that leads to")
      |> mes("the secret laboratory.^000000")
      |> next()
      |> select(["Enter", "Cancel"])

    case choice do
      1 ->
        warp(ctx, "kh_vila", 178, 72)

      2 ->
        close(ctx)

      _ ->
        ctx
    end
  end
end
