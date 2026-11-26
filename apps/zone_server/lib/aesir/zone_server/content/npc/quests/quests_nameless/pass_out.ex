defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.PassOut do
  @moduledoc """
  A rescue scene plays after the player passes out in the monastery.

  ## Behavior

  - Larjes revives the player and the investigation continues.

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
        map: "nameless_in",
        x: 15,
        y: 61,
        dir: 0,
        sprite: -1,
        name: "Pass Out",
        scope: :shared,
        unique_name: "Pass Out#Aru",
        trigger: {2, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 18 do
      ctx =
        ctx
        |> disablenpc("Out_from_Monastery")
        |> sc_start(:sc_blind, 600_000, 0)
        |> mes("^3355FFThe pressure on your")
        |> mes("stomach and the blood")
        |> mes("rushing to your head tells")
        |> mes("you someone is carrying you")
        |> mes("over his shoulder. He stops,")
        |> mes("and you hear a faint voice.^000000")
        |> next()
        |> mes("^3355FFThe faint voice steadily")
        |> mes("grows stronger and more")
        |> mes("distinct--someone's calling")
        |> mes("your name. You feel cold water")
        |> mes("trickle through your lips, and")
        |> mes("then you regain your senses.^000000")
        |> next()
        |> sc_end(:sc_blind)
        |> hideoffnpc("Larjes#Monastery")
        |> next()
        |> mes("That was too close...")
        |> mes("For a second there,")
        |> mes("I thought I lost you.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Larjes...? What...")
        |> mes("What happened?")
        |> mes("Ugh, my head...")
        |> next()
        |> mes("[Larjes]")
        |> mes("Try not to move for a while.")
        |> mes("I had a bad feeling waiting")
        |> mes("for you on the boat. Lucky")
        |> mes("thing. When I found you,")
        |> mes("these strange creatures")
        |> mes("were savagely attacking you!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("You saved me?")
        |> mes("Thank you. Do you")
        |> mes("happen to know what")
        |> mes("those creatures were?")
        |> next()
        |> mes("[Larjes]")
        |> mes("No clue. They looked")
        |> mes("like humans, but... They")
        |> mes("definitely weren't. Once")
        |> mes("I killed them, they all")
        |> mes("turned into sand.")
        |> next()
        |> hideoffnpc("Creature#Monas")

      ctx = emotion(ctx, :huk, playerattached(ctx))

      ctx =
        ctx
        |> emotion(:huk, getnpcid(ctx, "Larjes#Monastery"))
        |> mes("[Larjes]")
        |> mes("?!?!?!!!!!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("!!!!?!?!!!!!!")
        |> mes("Isn't... Isn't that...?")
        |> next()
        |> mes("[Larjes]")
        |> mes("It seems it's just like the")
        |> mes("creatures that kidnapped")
        |> mes("you, but... I wonder why")
        |> mes("he's not attacking us.")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I guess you'll have to go")
      |> mes("right up to him and ask.")
      |> set_char_var(:aru_monas, 19)
      |> close()
    else
      ctx
    end
  end
end
