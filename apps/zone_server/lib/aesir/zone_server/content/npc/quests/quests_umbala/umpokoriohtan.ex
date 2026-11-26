defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Umpokoriohtan do
  @moduledoc """
  Umpokoriohtan discusses his wife and his interest in other women.

  ## Behavior

  - He appears during the domestic dispute quest and changes dialogue after the language quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "um_in", x: 144, y: 45, dir: 5, sprite: 789, name: "Umpokoriohtan", scope: :shared}
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      if Enum.random(1..3) == 2 do
        ctx =
          ctx
          |> mes("[Umpokoriohtan]")
          |> mes("Hey there, cool cat.")
          |> mes("Don't mind the wife...")
          |> mes("Much as I love her,")
          |> mes("I know my obligations, ya dig?")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("If a man's got plenty, he's")
          |> mes("got to share it with those")
          |> mes("that got nothing to give.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("If a man's hands are good")
          |> mes("at healin', he's got to use")
          |> mes("those hands to help folks live.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("If a man's lips be good at")
          |> mes("singin', he's got to croon the")
          |> mes("songs we like to hear so much.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("But if sweet lovin' is golden,")
          |> mes("then baby...I got the Midas touch.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("Ooh...!")
          |> mes("...........")
          |> mes("My back--!")
          |> mes("Simmer down, baby, your turn is comin' in a minute~")

        ctx |> emotion(:rock, getnpcid(ctx, "Phrenetan")) |> emotion(:sweat) |> close()
      else
        ctx =
          ctx
          |> mes("[Umpokoriohtan]")
          |> mes("Man...sometimes my wife can")
          |> mes("be a lil' too rough, maybe")
          |> mes("even hurtful. But that's cool...")
          |> mes("it just means she's got fire.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("But someday, she'll have to")
          |> mes("learn that I gots to share")
          |> mes("this heart of mine with the ladies")
          |> mes("who really need a dose of vitamin")
          |> mes("lovin', ya dig? It's my obligation.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("Wainatan, Bertztan, Chabimatan...")
          |> mes("Those pretty girls been waitin'")
          |> mes("toooooo long. Don't worry,")
          |> mes("big daddy's comin' soon.")
          |> next()
          |> mes("[Umpokoriohtan]")
          |> mes("OOOH~! Phrenetan!")
          |> mes("Baby, why you gotta be rough?")
          |> mes("Hit me gently, ya dig??")
          |> mes("I don't mean to hurt you~")

        ctx |> emotion(:huk, getnpcid(ctx, "Phrenetan")) |> emotion(:kek) |> close()
      end
    else
      ctx
      |> emotion(:smile)
      |> mes("[Umpokoriohtan]")
      |> mes("Umbaumbah...........")
      |> mes("Umbahwooga woogawoo!")
      |> mes("Umbah umumbabah umbawoo gaga.")
      |> next()
      |> emotion(:fret)
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Umpokoriohtan")
  end
end
