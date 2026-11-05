defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Kiehl do
  @moduledoc """
  Kiehl confronts adventurers in the robot factory and orchestrates the final battles and escape.

  ## Behavior

  - Challenges the adventurer with robots, then reveals his motives and fights a duel.
  - Reveals his replacement body, opens the escape route, and leaves a ring to retrieve.
  - Announces the detonation countdown and resets the room when the timer expires.

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
        map: "kh_kiehl02",
        x: 50,
        y: 52,
        dir: 4,
        sprite: 902,
        name: "Kiehl",
        scope: :shared,
        unique_name: "Kiehl#Original"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer180000", ctx) do
    ctx
    |> stopnpctimer()
    |> mapannounce("kh_kiehl02", "Beeeeeeeeeeeeep~", 8, 16_711_680)
    |> donpcevent("KiehlRoom::OnReset")
  end

  def on_event("OnTimer179000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "1 second remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer178000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "2 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer177000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "3 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer176000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "4 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer175000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "5 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer170000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "10 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer160000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "20 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer150000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "30 seconds remaining until detonation", 8, 16_711_680)
  end

  def on_event("OnTimer120000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "1 minute remaining until detonation.", 8, 16_711_680)
  end

  def on_event("OnTimer60000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "2 minutes remaining until detonation.", 8, 16_711_680)
  end

  def on_event("OnTimer1000", ctx) do
    mapannounce(ctx, "kh_kiehl02", "3 minutes remaining until detonation.", 8, 16_711_680)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 200}]) == 0 do
      ctx
      |> mes("^3355FFJust a second...")
      |> mes("You're carrying too")
      |> mes("many items with you")
      |> mes("right now, so you'll")
      |> mes("need to free up more")
      |> mes("Inventory space first...^000000")
      |> close()
    else
      ctx |> cutin("kh_kiel01", 2) |> confront_kiehl()
    end
  end

  defp confront_kiehl(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 94 or quest_stage >= 106 ->
        ctx
        |> mes("[Kiehl]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> close()
        |> cutin("", 255)

      quest_stage == 94 and get_npc_var_of(ctx, "KHKilled", "KiehlRoom", 0) < 5 ->
        summon_robots(ctx)

      quest_stage == 94 and get_npc_var_of(ctx, "KHKilled", "KiehlRoom", 0) >= 5 ->
        ctx |> discuss_robots() |> resolve_duel()

      true ->
        resolve_duel(ctx)
    end
  end

  defp summon_robots(ctx) do
    ctx
    |> mes("[Kiehl]")
    |> mes("I'm surprised you made")
    |> mes("it this far, adventurer~")
    |> mes("I bid you welcome to my")
    |> mes("humble room. I assume that")
    |> mes("you've come for the Condensed")
    |> mes("Memory Scroll... my mind.")
    |> next()
    |> mes("[Kiehl]")
    |> mes("You can understand")
    |> mes("why I can't let you have it,")
    |> mes("so if you really want the")
    |> mes("Condensed Memory Scroll,")
    |> mes("then show me what you've got!")
    |> close()
    |> cutin("", 255)
    |> set_npc_var_of("KHKilled", "KiehlRoom", 0)
    |> summon_mob(
      mob_id: 1740,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> summon_mob(
      mob_id: 1739,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> summon_mob(
      mob_id: 1745,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> summon_mob(
      mob_id: 1740,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> summon_mob(
      mob_id: 1739,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> summon_mob(
      mob_id: 1745,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> summon_mob(
      mob_id: 1740,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlMobDead"
    )
    |> hideonnpc("Kiehl#Original")
  end

  defp discuss_robots(ctx) do
    ctx =
      ctx
      |> cutin("kh_kiel03", 2)
      |> mes("[Kiehl]")
      |> mes("Hmpf! You're pretty good.")
      |> mes("Father must have spent")
      |> mes("a lot of money to hire")
      |> mes("you. So has he sent")
      |> mes("you to kill me?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Kiel Hyre sent me to ask")
      |> mes("you to stop turning all of")
      |> mes("the Third Generation robots")
      |> mes("into killing machines! How")
      |> mes("can do something like that")
      |> mes("to other robots like you?")
      |> next()
      |> cutin("kh_kiel01", 2)
      |> mes("[Kiehl]")
      |> mes("Why not? It's said that man")
      |> mes("was made in the image of God.")
      |> mes("Well, robots were made in the")
      |> mes("image of man. You humans kill")
      |> mes("each other as much as you")
      |> mes("like, as far as I can tell.")
      |> next()
      |> mes("[Kiehl]")
      |> mes("It might not be ethical")
      |> mes("for me to provide weapons")
      |> mes("to humans that need them...")
      |> mes("But that's what they are.")
      |> mes("Weapons. It's more humane")
      |> mes("for robots to fight than humans.")
      |> next()
      |> mes("[Kiehl]")
      |> mes("Robots don't naturally")
      |> mes("feel pain or emotions...")
      |> mes("Not unless they're specially")
      |> mes("programmed. Sorry, but I don't")
      |> mes("plans to stop what I'm doing.")
      |> next()
      |> cutin("kh_kiel04", 2)
      |> mes("[Kiehl]")
      |> mes("I am sorry, but I don't have a plan to stop what I am doing.")
      |> mes("Aside from that, my father showed me a great example of")
      |> mes("how far a human could go for his own selfinishness by destroying a family.")
      |> mes("And therefore I don't think that he could create better robots than mine.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Humankind may not be")
    |> mes("perfect, but think about")
    |> mes("who you're working with!")
    |> mes("Rekenber is the epitome of")
    |> mes("human evil! How can you")
    |> mes("support them like this?")
    |> next()
    |> cutin("kh_kiel02", 2)
    |> mes("[Kiehl]")
    |> mes("I've had a long relationship")
    |> mes("with Rekenber. I'm fully aware")
    |> mes("of their capabilities. Do you")
    |> mes("remember the first room you")
    |> mes("passed on your way here, the")
    |> mes("one with all the toys?")
    |> next()
    |> mes("[Kiehl]")
    |> mes("I bet you didn't know that there")
    |> mes("were 5 Second Generation")
    |> mes("robots. Me, and my four other")
    |> mes("brothers and sisters. Father")
    |> mes("built that room so that all")
    |> mes("five of us could live together.")
    |> next()
    |> cutin("kh_kiel03", 2)
    |> mes("[Kiehl]")
    |> mes("I was the only one to")
    |> mes("survive. I returned to")
    |> mes("Father and even got a")
    |> mes("name. But yes, I know")
    |> mes("how bad Rekenber really is...")
    |> next()
    |> mes("[Kiehl]")
    |> mes("I don't... I don't want")
    |> mes("to talk about this any more.")
    |> mes("You've made me... Just leave.")
    |> mes("I think I will let you live.")
    |> next()
    |> cutin("", 255)
    |> mes("[Mitchell]")
    |> mes("Freeze!")
    |> mes("Kiehl Hyre, you're")
    |> mes("under arrest for creating")
    |> mes("and trading illegal weapons!")
    |> set_char_var(:KielHyreQuest, 100)
    |> hideoffnpc("Mitchell#KiehlRoom")
    |> hideoffnpc("Agent#KHAgent1")
    |> hideoffnpc("Agent#KHAgent2")
    |> hideoffnpc("Agent#KHAgent3")
    |> hideoffnpc("Agent#KHAgent4")
    |> next()
  end

  defp resolve_duel(ctx) do
    cond do
      get_char_var(ctx, :KielHyreQuest, 0) == 100 and
          get_npc_var_of(ctx, "KHKilledBoss", "KiehlRoom", 0) < 1 ->
        start_duel(ctx)

      get_char_var(ctx, :KielHyreQuest, 0) == 100 and
          get_npc_var_of(ctx, "KHKilledBoss", "KiehlRoom", 0) == 1 ->
        reveal_escape(ctx)

      get_char_var(ctx, :KielHyreQuest, 0) == 104 ->
        retrieve_ring(ctx)

      true ->
        ctx
        |> cutin("kh_kiel02", 2)
        |> mes("^3355FFKiehl's old")
        |> mes("robotic body")
        |> mes("stands alone,")
        |> mes("lifeless and silent.^000000")
        |> close()
        |> cutin("", 255)
    end
  end

  defp start_duel(ctx) do
    ctx
    |> set_npc_var_of("KHKilledBoss", "KiehlRoom", 0)
    |> cutin("kh_kiel01", 2)
    |> mes("[Kiehl]")
    |> mes("Ah, Schwarzwald Republic")
    |> mes("agents. Heh. I haven't had")
    |> mes("this many guests before.")
    |> mes("Well, I guess this means")
    |> mes("we'll have to fight after")
    |> mes("all, you and I. *Sigh* Pity.")
    |> next()
    |> mes("[Kiehl]")
    |> mes("First, in all fairness,")
    |> mes("let me take care of these")
    |> mes("nuisances. They're just")
    |> mes("mindlessly doing their")
    |> mes("jobs--sort of like robots-- but")
    |> mes("don't worry, they won't be hurt.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Nooooo!")
    |> specialeffect(:pf_fogwall, :area, "Mitchell#KiehlRoom")
    |> specialeffect(:pf_fogwall, :area, "Agent#KHAgent1")
    |> specialeffect(:pf_fogwall, :area, "Agent#KHAgent2")
    |> specialeffect(:pf_fogwall, :area, "Agent#KHAgent3")
    |> specialeffect(:pf_fogwall, :area, "Agent#KHAgent4")
    |> next()
    |> cutin("kh_kiel03", 2)
    |> mes("[Kiehl]")
    |> mes("And now, you and I can")
    |> mes("have a proper duel, human.")
    |> mes("I'm interested in seeing just")
    |> mes("how strong you really are~")
    |> close()
    |> cutin("", 255)
    |> summon_mob(
      mob_id: 1733,
      map: "kh_kiehl02",
      at: {50, 52},
      event: "KiehlRoom::OnKiehlDead"
    )
    |> hideonnpc("Kiehl#Original")
  end

  defp reveal_escape(ctx) do
    ctx =
      ctx
      |> cutin("kh_kiel02", 2)
      |> mes("[Kiehl]")
      |> mes("D-damn...!")
      |> mes("Well played, adventurer.")
      |> mes("Well played. I should have")
      |> mes("known that Father would send")
      |> mes("the very best after me. Still,")
      |> mes("you've failed to truly defeat me.")
      |> next()
      |> cutin("kh_kiel03", 2)
      |> mes("[Kiehl]")
      |> mes("I still have a few")
      |> mes("trump cards left")
      |> mes("I think... I'll take you")
      |> mes("to hell with me... Well,")
      |> mes("if robots can go there~")
      |> next()
      |> mapannounce("kh_kiehl02", "*Jeeeezzzgggg~ Geezzz~ Grrrr~ Clank~*", 1, "0xFF0000")
      |> mes("[Mitchell]")
      |> mes("No...! We're locked")
      |> mes("in the room! We're...")
      |> mes("We're trapped in here!")
      |> next()
      |> mes("[Kiehl]")
      |> mes("Yay~ Let's burn")
      |> mes("everything down~")
      |> next()
      |> mes("[Mitchell]")

    ctx
    |> mes("Quick, #{char_name(ctx, 0)},")
    |> mes("use Kiel Hyre's power")
    |> mes("device, the one that's")
    |> mes("supposed to mess with")
    |> mes("Kiehl's power supply!")
    |> mes("Hurry, use it right now!")
    |> next()
    |> mapannounce("kh_kiehl02", "*Gzzzz~ Gzzzz~*", 1, "0xFF0000")
    |> mes("[Kiehl]")
    |> mes("Wh-what? I c-can't")
    |> mes("move! This day is just")
    |> mes("full of surprises. Oh, well.")
    |> mes("I guess it's time for me to")
    |> mes("use my other trump card.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("What...?")
    |> mes("How many trump")
    |> mes("cards do you have?")
    |> next()
    |> mes("[????]")
    |> mes("I'm so disappointed...")
    |> mes("I can't believe none")
    |> mes("of you thought of this.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Who are you...?")
    |> mes("Show yourself!")
    |> next()
    |> mes("[????]")
    |> mes("Please.")
    |> mes("Don't insult me.")
    |> mes("You know this voice.")
    |> mes("It's been talking to")
    |> mes("you this entire time~")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Impossible...")
    |> mes("How can there")
    |> mes("be two of you...?!")
    |> next()
    |> hideoffnpc("Kiehl#Copy")
    |> next()
    |> reveal_replacement_body()
  end

  defp reveal_replacement_body(ctx) do
    ctx
    |> cutin("kh_kiel01", 0)
    |> mes("[Kiehl]")
    |> mes("Hahahahaha!")
    |> mes("I'm a robot!")
    |> mes("I can make extra")
    |> mes("bodies, switch brains")
    |> mes("with them. It's awfully")
    |> mes("convenient, let me tell you.")
    |> next()
    |> cutin("kh_kiel03", 2)
    |> mes("[Kiehl]")
    |> mes("Anyway, I don't mean to show")
    |> mes("off, but I suppose I better")
    |> mes("reveal to you my final trump")
    |> mes("card. First of all, I know all")
    |> mes("about you, Ms. Mitchell Layla~")
    |> next()
    |> mes("[Mitchell]")
    |> mes("What? How do you")
    |> mes("know my name?")
    |> next()
    |> mes("[Kiehl]")
    |> mes("Well, I have a few")
    |> mes("spies of my own...")
    |> mes("I'll allow him to explain...")
    |> next()
    |> expose_spy()
  end

  defp expose_spy(ctx) do
    ctx
    |> mes("[Masked Man]")
    |> mes("Mitchell...")
    |> mes("I'm sorry that")
    |> mes("you had to get")
    |> mes("involved in all this...")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Wolkeus? Wolkeus Kaiser?!")
    |> mes("You're the spy?! But you risked")
    |> mes("your life to save our president!")
    |> mes("No! Oh, God! How can this be")
    |> mes("happening?! Everything's just...")
    |> mes("This is all crazy! All of it!")
    |> next()
    |> mes("[Wolkeus]")
    |> mes("This is just the result")
    |> mes("of elaborate plans that")
    |> mes("were made years ago. I didn't")
    |> mes("expect you to be this surprised,")
    |> mes("Mitchell. It's the way the game")
    |> mes("is played. You know that.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Mister President...")
    |> mes("I failed you... I'm sorry...")
    |> next()
    |> mes("[Kiehl]")
    |> mes("Well, Kaiser, she took")
    |> mes("it pretty badly, but at least")
    |> mes("you're being gentlemanly")
    |> mes("about it. Well, I'd like for")
    |> mes("all of us to get better")
    |> mes("acquainted, but...")
    |> next()
    |> cutin("kh_kiel01", 2)
    |> mes("[Kiehl]")
    |> mes("We'd better say our")
    |> mes("farewells here. This")
    |> mes("place will be gone in")
    |> mes("five minutes. Ah, and")
    |> mes("Ms. Layla, you're coming")
    |> mes("with us. We have questions~")
    |> next()
    |> mes("[Kiehl]")
    |> mes("I'm curious as to what")
    |> mes("the president's plans are.")
    |> mes("Mister Kaiser, if you'll")
    |> mes("escort Ms. Layla, please...")
    |> next()
    |> mes("[Wolkeus Kaiser]")
    |> mes("...............................")
    |> mes("Sorry, Mitchell.")
    |> mes("I gotta do it.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("No, get away! Let me go!")
    |> mes("Let go of me, Wolkeus!")
    |> hideonnpc("Mitchell#KiehlRoom")
    |> hideonnpc("Agent#KHAgent1")
    |> hideonnpc("Agent#KHAgent2")
    |> hideonnpc("Agent#KHAgent3")
    |> hideonnpc("Agent#KHAgent4")
    |> next()
    |> cutin("kh_kiel02", 2)
    |> mes("[Kiehl]")
    |> leave_message()
  end

  defp leave_message(ctx) do
    ctx
    |> mes("Great, we're done with")
    |> mes("that ugly business. Now,")
    |> mes("where was I? Ah, right.")
    |> mes("Yes. I'm sorry. We don't")
    |> mes("have any more time to play.")
    |> next()
    |> mes("[Kiehl]")
    |> mes("Here, adventurer.")
    |> mes("I'm aware that my father")
    |> mes("sent you here to get this.")
    |> mes("Consider it my final gift")
    |> mes("to him. I'm surprised he left")
    |> mes("this ring inside me, though...")
    |> next()
    |> cutin("kh_kiel04", 2)
    |> mes("[Kiehl]")
    |> mes("I imagine that it must")
    |> mes("be precious to him. But")
    |> mes("I wonder why he placed")
    |> mes("it inside me? Well, anyway,")
    |> mes("I have a message I'd like")
    |> mes("for you to deliver to him.")
    |> next()
    |> cutin("kh_kiel01", 2)
    |> mes("[Kiehl]")
    |> mes("First... I guess we")
    |> mes("should get rid of this")
    |> mes("old thing. It was a good")
    |> mes("body, and it's served me")
    |> mes("well for 23 years. I'll miss")
    |> mes("it. Rest well, old Kiehl.")
    |> next()
    |> specialeffect(:devil)
    |> next()
    |> mes("[Kiehl]")
    |> mes("Now, this was the body")
    |> mes("that my father made.")
    |> mes("Please tell him that")
    |> mes("this means that we're")
    |> mes("no longer related to")
    |> mes("each other at all.")
    |> next()
    |> mes("[Kiehl]")
    |> mes("The body I'm using right now?")
    |> mes("I made it myself with the most")
    |> mes("advanced technology. Consider")
    |> mes("it... a Fourth Generation robot")
    |> mes("body if you will. Father will")
    |> mes("understand what I mean.")
    |> next()
    |> mes("[Kiehl]")
    |> mes("Anyway, please tell him")
    |> mes("that, and get his old ring")
    |> mes("out of my old robot body,")
    |> mes("and then give it to him. For")
    |> mes("now, let's get out of here: we")
    |> mes("just have 3 minutes to evacuate.")
    |> next()
    |> mes("[Kiehl]")
    |> mes("You're a worthy opponent,")
    |> mes("and a human I respect.")
    |> mes("I don't know if we'll meet")
    |> mes("again, but who knows?")
    |> mes("Anyway, I'll open up the")
    |> mes("exit for you. Farewell~")
    |> delitem(7504, 1)
    |> set_char_var(:KielHyreQuest, 104)
    |> hideonnpc("Kiehl#Copy")
    |> donpcevent("Kiehl_Room_Exit::OnEnable")
    |> enablenpc("Kiehl_Room_Exit")
    |> initnpctimer()
    |> cutin("", 255)
    |> close()
  end

  defp retrieve_ring(ctx) do
    ctx
    |> cutin("kh_kiel02", 2)
    |> mes("^3355FFYou retrieve the")
    |> mes("ring from the heart of")
    |> mes("Kiehl's old robotic body.^000000")
    |> give_item(7508, 1)
    |> set_char_var(:KielHyreQuest, 106)
    |> close()
    |> cutin("", 255)
  end
end
