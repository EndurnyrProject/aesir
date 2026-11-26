defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OddSlab do
  @moduledoc """
  A speaking slab guards the Z Gang's hideout.

  ## Behavior

  - Challenges eligible players to enter three passwords before transporting them.
  - Reacts differently while the entrance is in use or after the gang is defeated.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
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
        map: "moc_fild17",
        x: 209,
        y: 235,
        dir: 0,
        sprite: 111,
        name: "Odd Slab",
        scope: :shared,
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      (get_char_var(ctx, :zdan_edq, 0) == 15 or get_char_var(ctx, :zdan_edq, 0) == 16 or
         get_char_var(ctx, :zdan_edq, 0) == 17) and get_server_temp_var(ctx, "door2", 0) == 0 ->
        ctx =
          ctx
          |> mes("[Odd Slab]")
          |> mes("^FF0000*Creak Creak*")
          |> mes("Etner sspawrod.^000000")
          |> next()

        ctx = emotion(ctx, :huk, playerattached(ctx))

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("This slab is speaking")
          |> mes("to me! I... I think. Now")
          |> mes("where have I heard")
          |> mes("talking like this before?")
          |> next()
          |> mes("[Odd Slab]")
          |> mes("^FF0000*Creak Creak*")
          |> mes("Etner sspawrod.^000000")
          |> next()

        ctx = emotion(ctx, :aha, playerattached(ctx))

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Oh, right! This is that")
          |> mes("trashy language, Aegye,")
          |> mes("that Gooho Ahn told me")
          |> mes("about. It still sounds")
          |> mes("like... A poor excuse")
          |> mes("for language to me.")
          |> next()
          |> mes("[Odd Slab]")
          |> mes("^FF0000*Creak Creak*")
          |> mes("Etner sspawrod.^000000")
          |> next()

        {ctx, first_password} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Well, I guess")
          |> mes("I should talk to it. Um...")
          |> next()
          |> input(:string)

        ctx = set_local(ctx, :"input$", first_password)

        if get_local(ctx, :"input$", "") == "Weii arr prowd Z G gna" do
          ctx =
            ctx
            |> mes("[Odd Slab]")
            |> mes("^FF0000*Creak Creak*")
            |> mes("Etner n2d sspawrod.^000000")
            |> next()

          {ctx, second_password} =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Whoa! It's saying")
            |> mes("something different now!")
            |> mes("I must be doing alright.")
            |> mes("Now what do I say?")
            |> next()
            |> input(:string)

          ctx = set_local(ctx, :"input$", second_password)

          if get_local(ctx, :"input$", "") == "Aynoen hwo sspotp uys" do
            ctx =
              ctx
              |> mes("[Odd Slab]")
              |> mes("^FF0000*Creak Creak*")
              |> mes("Etner r3d sspawrod.^000000")
              |> next()

            {ctx, third_password} =
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Heh! I'm on the right")
              |> mes("track. Now what do I say?")
              |> next()
              |> input(:string)

            ctx = set_local(ctx, :"input$", third_password)

            if get_local(ctx, :"input$", "") == "wlil eb kckide on htier ssa!" do
              ctx =
                ctx |> mes("[Odd Slab]") |> mes("*Creak Creak*") |> mes("*Creak Creak*") |> next()

              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("Um... Now what...?")
                |> next()

              if get_server_temp_var(ctx, "door2", 0) == 0 do
                ctx = ctx |> set_server_temp_var("door2", 1) |> mes("Waaaah! Waaah!") |> next()

                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("What th--?! What's")
                |> mes("happening?! I'm being")
                |> mes("sucked away somewhere!")
                |> changequest(3132, 3133)
                |> set_char_var(:zdan_edq, 16)
                |> close2()
                |> warp("z_agit", 98, 40)
              else
                ctx =
                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("Hm? Did I do something")
                  |> mes("wrong? It just stopped")
                  |> mes("working all of a sudden.")
                  |> next()
                  |> mes("[Odd Slab]")
                  |> mes("^FF0000Rrsoy, rrsoy.")
                  |> mes("Ai cn'at elt yoo ni ofr nwo. Plzea ecmo ckba tela.^000000")
                  |> next()
                  |> mes("^666666*Pzzzzz*^000000")
                  |> next()

                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("I think...")
                |> mes("I think I should")
                |> mes("try this again.")
                |> close()
              end
            else
              wrong_password(ctx)
            end
          else
            wrong_password(ctx)
          end
        else
          wrong_password(ctx)
        end

      (get_char_var(ctx, :zdan_edq, 0) == 15 or get_char_var(ctx, :zdan_edq, 0) == 16 or
         get_char_var(ctx, :zdan_edq, 0) == 17) and get_server_temp_var(ctx, "door2", 0) > 0 ->
        ctx = ctx |> mes("[Odd Slab]") |> mes("*Creak Creak*") |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("This slab looks pretty")
        |> mes("strange. Is it making")
        |> mes("noises? Hmm... Maybe this")
        |> mes("is a clue to the Z Gang!")
        |> mes("I'll come back later")
        |> mes("to investigate this~")
        |> close()

      get_char_var(ctx, :zdan_edq, 0) > 17 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("This used to be")
        |> mes("where the Z Gang")
        |> mes("would hide out.")
        |> mes("Good riddance! ")
        |> close()

      true ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("This is a peculiar")
        |> mes("looking slab. It sounds")
        |> mes("like... What are those")
        |> mes("noises? Huh. Weird.")
        |> mes("It's like it's just")
        |> mes("talking gibberish.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    ctx
    |> set_server_temp_var("zdan", 0)
    |> set_server_temp_var("door2", 0)
    |> set_server_temp_var("mosnter", 0)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :zdan_edq, 0) == 15 do
      ctx = ctx |> mes("^FF0000*Creak Creak*^000000") |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Did I just...")
      |> mes("Hear something")
      |> mes("around here?")
      |> close()
    else
      ctx
    end
  end

  defp wrong_password(ctx) do
    ctx = ctx |> mes("[Odd Slab]") |> mes("^666666*Pzzzzz*^000000") |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh? This talking slab")
    |> mes("thing isn't working now.")
    |> mes("Hello? What happened to you?")
    |> mes("Hey! Talk to me, will you?")
    |> set_server_temp_var("door2", 0)
    |> close()
  end
end
