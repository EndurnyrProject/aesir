defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Historian135168 do
  @moduledoc """
  A historian compares versions of the kingdom’s founding song.

  ## Behavior

  - Asks the player to recite the song and records correct or incorrect lyrics.
  - Directs the player to the child who taught him his version.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_01",
        x: 135,
        y: 168,
        dir: 3,
        sprite: 754,
        name: "Historian",
        scope: :shared,
        unique_name: "Historian#prt03"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 do
      overweight(ctx)
    else
      talk_at_stage(ctx, get_char_var(ctx, :prt_curse, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp talk_at_stage(ctx, 8), do: discuss_song(ctx)
  defp talk_at_stage(ctx, 9), do: retry_song(ctx)
  defp talk_at_stage(ctx, 10), do: find_singer(ctx)
  defp talk_at_stage(ctx, _stage), do: greeting(ctx)

  defp discuss_song(ctx) do
    ctx =
      ctx
      |> mes("[Historian Mondo]")
      |> mes("Excuse me...")
      |> mes("But if you don't have")
      |> mes("anything important for")
      |> mes("me, then would you")
      |> mes("please leave? I have")
      |> mes("research to attend to...")
      |> next()

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm sorry, but Ms. Rodafrian")
      |> mes("wanted me to ask you for the")
      |> mes("lyrics of some song describing")
      |> mes("the Rune-Midgarts Kingdom's")
      |> mes("founding. Would you tell")
      |> mes("them to me for her?")
      |> next()
      |> mes("[Historian Mondo]")
      |> mes("Rodafrian? Oh, she must")
      |> mes("mean that old children's")
      |> mes("song. How did it go now?")
      |> mes("Ah, now I remember...")
      |> next()
      |> mes("[Historian Mondo]")
      |> mes("^FF0000*The great serpent*^000000")
      |> mes("^FF0000*swallowed the sea.*^000000")
      |> mes("^FF0000*The eagle of the rainbow*^000000")
      |> mes("^FF0000*swallowed the serpent.*^000000")
      |> mes("^FF0000*Then snake scales grew on*^000000")
      |> mes("^FF0000*the eagle, and it slowly died.*^000000")
      |> next()
      |> select(["...........?"])

    {ctx, _} =
      ctx
      |> mes("[Historian Mondo]")
      |> mes("Yes, I know: the song")
      |> mes("is rather morbid, despite")
      |> mes("the fact that it's sung like")
      |> mes("such a happy song. Sometimes")
      |> mes("these little songs are supposed")
      |> mes("to scare kids into doing good.")
      |> next()
      |> select(["Excuse me..."])

    ctx =
      ctx
      |> mes("[Historian Mondo]")
      |> mes("Hm? You look confused.")
      |> mes("Did you have a question")
      |> mes("to ask me about the song?")
      |> next()

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Actually, I heard")
      |> mes("a different version")
      |> mes("of this song, so I was")
      |> mes("wondering why the lyrics")
      |> mes("would be different...")
      |> next()
      |> mes("[Historian Mondo]")
      |> mes("Really now?")
      |> mes("Well then, let me")
      |> mes("hear the version that")
      |> mes("you've heard, starting")
      |> mes("from the beginning.")
      |> next()
      |> scoped_call([], &recite_song/2)

    ctx
  end

  defp retry_song(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Historian Mondo]")
      |> mes("Ah, would you tell me")
      |> mes("the lyrics of the version of")
      |> mes("the Rune-Midgarts Kingdom")
      |> mes("founding myth song that")
      |> mes("you happened to hear?")
      |> next()
      |> scoped_call([], &recite_song/2)

    ctx
  end

  defp find_singer(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Historian Mondo]")
      |> mes("Interesting...")
      |> mes("The version you heard")
      |> mes("from Karlomoff is different")
      |> mes("than the one I know. It's")
      |> mes("possible that his version")
      |> mes("is the most authentic.")
      |> next()
      |> mes("[Historian Mondo]")
      |> mes("After all, I learned")
      |> mes("the version I know")
      |> mes("by listening to a")
      |> mes("little kid sing it.")
      |> next()
      |> select(["A kid?"])

    ctx
    |> mes("[Historian Mondo]")
    |> mes("Yeah. My guess? The version")
    |> mes("that the kid sang might have")
    |> mes("changed as it was transmitted")
    |> mes("by mouth through the generations. If you want to learn more, you")
    |> mes("should probably find that kid.")
    |> next()
    |> mes("[Historian Mondo]")
    |> mes("Anyway, Karlomoff may have")
    |> mes("the most accurate version of")
    |> mes("the song since he's very good")
    |> mes("at procuring and authenticating")
    |> mes("historical written records and")
    |> mes("documents. It's his specialty.")
    |> next()
    |> mes("[Historian Mondo]")
    |> mes("Ah, if you want to learn more,")
    |> mes("then you should try to find the")
    |> mes("kid that was singing the song.")
    |> mes("Hmm, he might be around ^3131DDthe")
    |> mes("river near here^000000. Hopefully it")
    |> mes("won't be too hard to find him.")
    |> next()
    |> mes("[Historian Mondo]")
    |> mes("Once you're able to talk")
    |> mes("to that kid, go ahead and")
    |> mes("report back to Rodafrian.")
    |> mes("She probably needs to know")
    |> mes("soon, and I can talk to that")
    |> mes("little kid at my leisure, so...")
    |> next()
    |> mes("[Historian Mondo]")
    |> mes("Well then, I hope you")
    |> mes("find what you're looking")
    |> mes("for. Good luck in your")
    |> mes("travels, adventurer.")
    |> set_char_var(:prt_curse, 11)
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Historian Mondo]")
    |> mes("Isn't this such")
    |> mes("a beautiful place?")
    |> mes("It's no wonder that")
    |> mes("ancient peoples chose")
    |> mes("to live around here...")
    |> close()
  end

  defp recite_song(ctx, _args) do
    {ctx, first_line} =
      ctx |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]")) |> input(:string)

    ctx = set_local(ctx, :"line$", first_line)

    ctx =
      if get_local(ctx, :"line$", "") == "The great serpent swallowed the sea." do
        ctx
        |> set_local(:total, get_local(ctx, :total, 0) + 1)
        |> mes("*The great serpent*")
        |> mes("*swallowed the sea.*")
      else
        mes(ctx, Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*"))
      end

    {ctx, second_line} = input(ctx, :string)
    ctx = set_local(ctx, :"line$", second_line)

    ctx =
      if get_local(ctx, :"line$", "") == "The eagle of the rainbow swallowed the serpent." do
        ctx
        |> set_local(:total, get_local(ctx, :total, 0) + 1)
        |> mes("*The eagle of the rainbow*")
        |> mes("*swallowed the serpent.*")
      else
        mes(ctx, Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*"))
      end

    {ctx, third_line} = input(ctx, :string)
    ctx = set_local(ctx, :"line$", third_line)

    ctx =
      if get_local(ctx, :"line$", "") == "Then the eagle built its nest." do
        set_local(ctx, :total, get_local(ctx, :total, 0) + 1)
      else
        ctx
      end

    {ctx, fourth_line} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*"))
      |> input(:string)

    ctx = set_local(ctx, :"line$", fourth_line)

    ctx =
      if get_local(ctx, :"line$", "") == "A nest upon the swallowed sea." do
        set_local(ctx, :total, get_local(ctx, :total, 0) + 1)
      else
        ctx
      end

    ctx = mes(ctx, Rathena.concat(Rathena.concat("*", get_local(ctx, :"line$", "")), "*"))

    ctx =
      if get_local(ctx, :total, 0) == 4 do
        set_char_var(ctx, :prt_curse, 10)
      else
        ctx = next(ctx)

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wait, wait...")
        |> mes("I think I messed up!")
        |> mes("(Those weren't the")
        |> mes("correct lyrics...)")
        |> set_char_var(:prt_curse, 9)
      end

    {close(ctx), nil}
  end
end
