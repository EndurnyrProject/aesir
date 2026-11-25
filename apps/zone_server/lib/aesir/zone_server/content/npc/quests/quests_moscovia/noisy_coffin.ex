defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.NoisyCoffin do
  @moduledoc """
  A noisy coffin challenges the player to silence it for Baba Yaga.

  ## Behavior

  - The player must perform a sequence of actions to quiet the coffin and advance the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun02",
        x: 65,
        y: 232,
        dir: 0,
        sprite: 801,
        name: "Noisy Coffin",
        scope: :shared,
        unique_name: "Noisy Coffin#rus36"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :rhea_rus_main, 0)

    cond do
      progress < 19 -> hear_coffin(ctx, progress)
      progress == 20 -> silence_coffin(ctx, true)
      progress == 42 -> silence_coffin(ctx, false)
      true -> ctx |> mes("[Noisy Coffin]") |> mes(".............................") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp hear_coffin(ctx, progress) do
    ctx =
      ctx
      |> mes("[Noisy Coffin]")
      |> mes("Isn't it good to be alive? Isn't it to live?")
      |> next()
      |> mes("[Noisy Coffin]")
      |> mes("Don't you want to exchange lives with me? Exchange with me, exchange!")

    if progress < 16 do
      close(ctx)
    else
      ctx =
        ctx
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ehh, that's one noisy coffin.")
        |> next()
        |> mes("[Noisy Coffin]")
        |> mes("I was alive! I was alive!")
        |> mes(
          "What is different between you and me? Why are you still alive? Why didn't you die? Why did I die?"
        )
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("... How can I silence him...")
        |> next()

      case try_silencing(ctx) do
        {:cancelled, ctx} -> ctx
        {:ok, ctx} -> finish_attempt(ctx)
      end
    end
  end

  defp finish_attempt(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) < 20 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("... Not effective...")
      |> set_char_var(:rhea_rus_main, 16)
      |> close()
    else
      silence_coffin(ctx, true)
    end
  end

  defp silence_coffin(ctx, advance?) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(".............If you make noise once more, you will see more than you imagine...")
      |> next()
      |> mes("[Noisy Coffin]")
      |> mes("................................")
      |> emotion(:think)
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hu, the job has been done.")
      |> mes("Let's get back to Baba Yaga.")

    ctx = if advance?, do: set_char_var(ctx, :rhea_rus_main, 42), else: ctx
    close(ctx)
  end

  defp try_silencing(ctx) do
    if get_local(ctx, :break_while, 0) == 0 do
      {ctx, choice} = select(ctx, ["Pray", "Sing a hymn", "Pour Holy Water on him", "Kick him"])

      if choice in 1..4 do
        ctx =
          case choice do
            1 ->
              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("...I'll pray.")
                |> next()

              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("Heaven, earth, and wind belong to God, there is no place for evil.")
                |> specialeffect(:blessing)
                |> next()
                |> mes("[Noisy Coffin]")

              if get_char_var(ctx, :rhea_rus_main, 0) == 17 do
                ctx |> mes("Heek, heeee! Heeeeeek!") |> set_char_var(:rhea_rus_main, 18)
              else
                ctx = ctx |> mes("What was that? What was that for? Was it fun?") |> next()

                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("......................................")
                |> set_local(:break_while, 1)
              end

            2 ->
              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("Hmm, hmm! I'll sing a hymn. The first phrase 'Holy god against evils'!!")
                |> next()

              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("- The covetous, the perverse -")
                |> mes("- All the evils hateful -")
                |> mes("- Will be droven off this land -")
                |> specialeffect(:gloria)
                |> next()
                |> mes("[Noisy Coffin]")

              if get_char_var(ctx, :rhea_rus_main, 0) == 18 do
                ctx |> mes("Heek, heeee! Heeeeeek!") |> set_char_var(:rhea_rus_main, 19)
              else
                ctx =
                  ctx
                  |> mes(
                    "Perverse! The perverse!! Drive away!! What was that song?! Was it fun?!"
                  )
                  |> next()

                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("......................................")
                |> set_local(:break_while, 1)
              end

            3 ->
              if Rathena.truthy?(count_item(ctx, 523)) do
                ctx =
                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("If you don't shut up, I will pour Holy Water on you!")
                  |> next()
                  |> mes(
                    "- You open the bottle of Holy Water and pour it around the coffin carefully !! -"
                  )
                  |> specialeffect(:sphere)
                  |> next()
                  |> mes("[Noisy Coffin]")

                if get_char_var(ctx, :rhea_rus_main, 0) == 16 do
                  ctx
                  |> mes("Heek, heeee! Heeeeeek!")
                  |> delitem(523, 1)
                  |> set_char_var(:rhea_rus_main, 17)
                else
                  ctx =
                    ctx
                    |> mes("Ah, cold! No, it's cool! Was it fun? Was it fun?!")
                    |> delitem(523, 1)
                    |> next()

                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("......................................")
                  |> set_local(:break_while, 1)
                end
              else
                ctx =
                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("Yeah, where's the Holy water?")
                  |> next()

                ctx =
                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("...... I don't have any...")
                  |> next()

                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("......................................")
                |> set_local(:break_while, 1)
              end

            4 ->
              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("...If you don't shut up...")
                |> mes("......I will kick you!!")
                |> next()
                |> mes(
                  "- You close your eyes, take a deep breathe and kick the coffin with the might of God !! -"
                )
                |> next()
                |> mes("[Noisy Coffin]")

              ctx =
                if get_char_var(ctx, :rhea_rus_main, 0) == 19 do
                  ctx
                  |> mes("Heeeek! Heeeeeee!!!! I am scared! Stop it!!")
                  |> specialeffect(:holyhit)
                  |> set_char_var(:rhea_rus_main, 20)
                else
                  ctx = ctx |> mes("Slam! Slam! I like noise! Do it more, more, more!") |> next()

                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("......................................")
                end

              set_local(ctx, :break_while, 1)
          end

        ctx |> next() |> try_silencing()
      else
        {:cancelled, ctx}
      end
    else
      {:ok, ctx}
    end
  end
end
