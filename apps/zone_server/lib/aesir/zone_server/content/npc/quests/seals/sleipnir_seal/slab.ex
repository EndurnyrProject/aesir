defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Slab do
  @moduledoc """
  An engraved stone slab holding a hidden word puzzle in the Sleipnir Seal quest.

  ## Behavior

  - Outside the Sleipnir seal phase it is only a weathered slab with unreadable writing.
  - On the right route, reading it marks the slab as found.
  - Once the friar's story has been heard, pressing the three highlighted words in order makes
    the hidden writing appear for a moment and advances the quest; a wrong word ends the attempt.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
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
        map: "que_god01",
        x: 20,
        y: 48,
        dir: 0,
        sprite: 111,
        name: "Slab",
        scope: :shared,
        unique_name: "Slab#G"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx
        |> describe_ancient_writing()
        |> close()

      get_char_var(ctx, :god_sl_1, 0) not in [41, 12, 23, 34] ->
        ctx
        |> plain_engraving()
        |> next()
        |> describe_ancient_writing()
        |> next()
        |> describe_warmth()
        |> close()

      true ->
        read_slab(ctx, get_char_var(ctx, :god_sl_2, 0))
    end
  end

  defp read_slab(ctx, stage) when stage in [1, 2] do
    ctx
    |> highlighted_engraving()
    |> set_char_var(:god_sl_2, 2)
    |> next()
    |> describe_ancient_writing()
    |> next()
    |> describe_warmth()
    |> close()
  end

  defp read_slab(ctx, 3) do
    ctx =
      ctx
      |> mes("....whgks ^ff00ffdirdnl^000000sjs wkrdjswhgks whdtnfn")
      |> mes("............djswhgks wkdusdnlrnlfn")
      |> mes(".......whsjs rhf tk dmqsjs rj ehddjfn")
      |> mes("wkdusgks ^ff00fftkaryf^000000dnl durjfflrhsjs wkrdjswhgks ......")
      |> mes("wkrdjswhgks shfh wkrdjswhgks wkdus wkr...")
      |> mes("^ff00ffghswka^000000gks.........fusjs tmld.........")
      |> next()
      |> mes(
        "^3355FFUpon taking a closer look at the stone slab, you see that there are small devices in the crevices of each engraved letter in one of the words."
      )
      |> next()
      |> highlighted_engraving()
      |> next()

    with {:ok, ctx} <- press_word(ctx, "dirdnl"),
         {:ok, ctx} <- press_word(ctx, "tkaryf"),
         {:ok, ctx} <- press_word(ctx, "ghswka") do
      reveal_hidden_writing(ctx)
    else
      {:miss, ctx} -> ctx
    end
  end

  defp read_slab(ctx, _stage) do
    ctx
    |> plain_engraving()
    |> next()
    |> mes(
      "^3355FFThis slab of stone has been weathered with time, and its surface is engraved with writing from a strange language.^000000"
    )
    |> next()
    |> mes("^3355FFStrangely enough, the surface of the stone is emitting heat.^000000")
    |> close()
  end

  defp press_word(ctx, word) do
    {ctx, input} = input(ctx, :string)
    ctx = set_local(ctx, :"input$", input)

    if input == word do
      {:ok, ctx |> word_pressed(word) |> next() |> highlighted_engraving() |> next()}
    else
      {:miss, word_missed(ctx, word)}
    end
  end

  defp word_pressed(ctx, "dirdnl") do
    ctx
    |> mes("Zap~")
    |> mes(
      "^3355FFAs you press the word '^ff0000dirdnl^3355FF,' the slab emitted a strange beeping noise but nothing else happened. Perhaps you must press some of the other words.^000000"
    )
  end

  defp word_pressed(ctx, "tkaryf") do
    ctx
    |> mes("^3355FFYou press the word '^ff0000tkaryf^3355FF,' and another beep was emitted from")
    |> mes("the slab.^000000")
  end

  defp word_pressed(ctx, "ghswka") do
    mes(
      ctx,
      "^3355FFYou press on the word '^ff0000ghswka^3355FF,' resulting in an affirmative beep. Nothing has still happened, so perhaps you must press another word.^000000"
    )
  end

  defp word_missed(ctx, "ghswka") do
    ctx
    |> mes("You touched a word ^ff0000#{get_local(ctx, :input, 0)}^000000, nothing happened.")
    |> mes("You decided to think up something different.")
    |> close()
  end

  defp word_missed(ctx, _word) do
    ctx
    |> mes("^3355FFNothing happened.")
    |> mes("Perhaps that word")
    |> mes("is not on the slab.^000000")
    |> close()
  end

  defp reveal_hidden_writing(ctx) do
    ctx
    |> mes("^666666*Eeeeeeeeee~*^000000")
    |> next()
    |> mes("^3355FFThe slab began")
    |> mes("to vibrate and the")
    |> mes("engraved letters slowly")
    |> mes("disappeared, revealing")
    |> mes("a new set of words underneath.^000000")
    |> next()
    |> mes("wkrdjswhgks dirdnlsjs wkrdjswhgks whdtnfh")
    |> mes("wkrdjswhgks dldgnsdjs wkrdjswhgks wkdusdnlrnlfn")
    |> mes("thfdh duTsjswhsjs rhf tk dmqsjs rj ehddjfn")
    |> mes("wkdusgks tkaryfdnl durjfflrhsjs wkrdjswhgks tkatnfu")
    |> mes("wkrdjswhgks shfh wkrdjswhgks wkdus wkrdjswhgks dldgns")
    |> mes("ghswkagks tkatnfusjs tmldaldgks akrnl")
    |> next()
    |> mes("^3355FFYou still don't")
    |> mes("understand what is")
    |> mes("written on the slab.^000000")
    |> set_char_var(:god_sl_2, 4)
    |> next()
    |> mes(
      "After a while, the original engraving on the slab re-appeared, once again concealing the writing underneath. It seems you can only reveal the hidden letters temporarily."
    )
    |> close()
  end

  defp highlighted_engraving(ctx) do
    ctx
    |> mes("....whgks ^ff00ffdirdnl^000000sjs wkrdjswhgks whdtnfb")
    |> mes("............djswhgks wkdusdnlrnlfn")
    |> mes(".......whsjs rhf tk dmqsjs rj ehddjfn")
    |> mes("wkdusgks ^ff00fftkaryf^000000dnl durjfflrhsjs wkrdjswhgks ......")
    |> mes("wkrdjswhgks shfh wkrdjswhgks wkdus wkr...")
    |> mes("^ff00ffghswka^000000gks ........fusjs tmld.........")
  end

  defp plain_engraving(ctx) do
    ctx
    |> mes("....whgks dirdnlsjs wkrdjswhgks whdtnfn")
    |> mes("............djswhgks wkdusdnlrnlfn")
    |> mes(".......whsjs rhf tk dmqsjs rj ehddjfn")
    |> mes("wkdusgks tkaryfdnl durjfflrhsjs wkrdjswhgks ......")
    |> mes("wkrdjswhgks shfh wkrdjswhgks wkdus wkr...")
    |> mes("ghswkagks .........fusjs tmld.........")
  end

  defp describe_ancient_writing(ctx) do
    mes(
      ctx,
      "^3355FFThere is some writing engraved on this slab of stone. Since you can't read it and the stone looks weathered with time, it seems to be written in an ancient language.^000000"
    )
  end

  defp describe_warmth(ctx) do
    mes(
      ctx,
      "^3355FFUpon touching the slab's surface, you feel that it is surprisingly warm. Perhaps there is more to this slab than meets the eye.^000000"
    )
  end
end
