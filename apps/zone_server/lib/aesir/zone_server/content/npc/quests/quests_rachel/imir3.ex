defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Imir3 do
  @moduledoc """
  Reveals the sanctuary’s secret and Niren’s intervention.

  ## Behavior

  - Shows the Ymir fragments, advances the quest, and sends the adventurer back to Rachel.

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
        map: "que_san04",
        x: 119,
        y: 203,
        dir: 0,
        sprite: -1,
        name: "imir3",
        scope: :shared,
        unique_name: "imir3#rachel",
        trigger: {7, 7}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ra_tem_q, 0) == 21 do
      ctx
      |> mes("^3355FFNo wonder this object")
      |> mes("in the water seems so")
      |> mes("familiar: it's a Ymir's")
      |> mes("Heart Piece! In fact, there's")
      |> mes("dozens of them just lying here.^000000")
      |> next()
      |> mes("^3355FFWhy would so many of these")
      |> mes("powerful artifacts be here")
      |> mes("in the Holy Ground? Perhaps")
      |> mes("this is the secret that the")
      |> mes("priests are trying to keep.^000000")
      |> next()
      |> hideoffnpc("High Priestess Niren#r2")
      |> cutin("ra_gwoman", 2)
      |> mes("[High Priestess Niren]")
      |> mes("How dare you intrude")
      |> mes("the Holy Ground! Identify")
      |> mes("yourself! I'll have you tried!")
      |> next()
      |> cutin("ra_gwoman2", 2)
      |> mes("[High Priestess Niren]")
      |> mes("O-oh! It's you, the")
      |> mes("adventurer recommended")
      |> mes("by Bekento. Hm. I apologize")
      |> mes("for snapping at you like")
      |> mes("that. Didn't you know that")
      |> mes("no one's allowed here?")
      |> next()
      |> cutin("ra_gwoman", 2)
      |> mes("[High Priestess Niren]")
      |> mes("Hmm. Well, you Rune-Midgarts")
      |> mes("adventurers are famous for your")
      |> mes("skills and abilities, but this")
      |> mes("was not expected. I mean, we")
      |> mes("made sure this place was")
      |> mes("absolutely secure.")
      |> next()
      |> cutin("ra_gwoman2", 2)
      |> mes("[High Priestess Niren]")
      |> mes("What's done is done...")
      |> mes("I warned Bekento that he")
      |> mes("might cause trouble for you,")
      |> mes("but it seems that you've")
      |> mes("caused trouble for him.")
      |> next()
      |> mes("[High Priestess Niren]")
      |> mes("Understand this:")
      |> mes("most intruders are")
      |> mes("severely punished, but")
      |> mes("because of my friendship")
      |> mes("with Bekento, I'm letting")
      |> mes("you off easy. Remember that.")
      |> next()
      |> sc_start(:sc_blind, 600_000, 0)
      |> mes("^3355FFNiren began to chant")
      |> mes("in a low voice, and your")
      |> mes("eyelids grow heavier as you")
      |> mes("grow drowsier and sleepier...^000000")
      |> close2()
      |> cutin("", 255)
      |> hideonnpc("High Priestess Niren#r2")
      |> set_char_var(:ra_tem_q, 22)
      |> changequest(8104, 8105)
      |> warp("rachel", 163, 152)
    else
      ctx
    end
  end
end
