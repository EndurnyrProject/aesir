defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.MysteriousWoman do
  @moduledoc """
  Esuna directs the player through Secret Wing's investigation.

  ## Behavior

  - Gives instructions and evidence at successive stages of the investigation.
  - Warns the player when Secret Wing is compromised.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_fild01",
        x: 66,
        y: 219,
        dir: 4,
        sprite: 859,
        name: "Mysterious Woman",
        scope: :shared
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Mysterious Woman")

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :lhz_boss, 0)

    cond do
      quest == 26 and checkweight(ctx, [{7343, 1}]) != 1 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      quest == 26 ->
        ctx
        |> mes("[Esuna]")
        |> mes("I've been waiting for you.")
        |> mes("We don't have much time,")
        |> mes("so I'll explain quickly. Your")
        |> mes("mission is to sneak into the")
        |> mes("Rekenber Corporation and")
        |> mes("steal incriminating evidence.")
        |> next()
        |> mes("[Esuna]")
        |> mes("However, this place won't")
        |> mes("be easy to infiltrate and")
        |> mes("there'll be more security")
        |> mes("because they learned about")
        |> mes("what happened with Shinokas")
        |> mes("and... and Jargeah. Jargeah...")
        |> next()
        |> mes("[Esuna]")
        |> mes("You'll need to acquire")
        |> mes("identification through one")
        |> mes("of our agents who's managed")
        |> mes("to get in really deep without")
        |> mes("arousing any suspicion.")
        |> next()
        |> mes("[Esuna]")
        |> mes("Afterwards, find the")
        |> mes("^FF0000Secret Archive^000000, disable the")
        |> mes("security system and steal")
        |> mes("that evidence as quickly as")
        |> mes("possible. Understood?")
        |> next()
        |> mes("[Esuna]")
        |> mes("For now, use the pass you")
        |> mes("have for the Rekenber buildings")
        |> mes("and meet up with Agent ^FF0000Lestin^000000.")
        |> mes("He'll explain everything else,")
        |> mes("so be careful and don't let")
        |> mes("them get suspicious of you!")
        |> set_char_var(:lhz_boss, 27)
        |> changequest(12_024, 12_025)
        |> close2()
        |> disablenpc("Mysterious Woman")

      quest == 27 ->
        ctx
        |> mes("[Esuna]")
        |> mes("Use the pass that you")
        |> mes("have to enter the Rekenber")
        |> mes("buildings and find Secret")
        |> mes("Agent Lestin. Remember")
        |> mes("that he's undercover...")
        |> close()

      quest < 36 ->
        ctx |> mes("[Esuna]") |> mes(".........") |> close()

      quest == 36 ->
        ctx
        |> mes("[Esuna]")
        |> mes("Good work.")
        |> mes("Please bring this file")
        |> mes("to President Weierstrass")
        |> mes("right away. We'll also be")
        |> mes("directly sending information")
        |> mes("as a safeguard measure.")
        |> next()
        |> mes("[Esuna]")
        |> mes("I know it's sudden, but")
        |> mes("there's a new development.")
        |> mes("I can't explain it now, but you")
        |> mes("have to check on the president")
        |> mes("for me first. Plus, this new")
        |> mes("intel needs to be confirmed...")
        |> set_char_var(:lhz_boss, 37)
        |> close2()
        |> disablenpc("Mysterious Woman")

      quest < 38 ->
        ctx |> mes("[Esuna]") |> mes("........") |> mes(".....") |> close()

      quest == 38 ->
        ctx
        |> mes("[Esuna]")
        |> mes("You're back. Listen,")
        |> mes("you could not have helped")
        |> mes("us out at a worse time. We")
        |> mes("just learned that something")
        |> mes("horrible has happened...")
        |> next()
        |> mes("[Esuna]")
        |> mes("I can't give you all")
        |> mes("the details now, but")
        |> mes("you've got to give this")
        |> mes("file to the president as")
        |> mes("quickly as you can. Hurry!")
        |> set_char_var(:lhz_boss, 39)
        |> give_item(7343, 1)
        |> close2()
        |> disablenpc("Mysterious Woman")

      quest == 39 ->
        ctx
        |> mes("[Esuna]")
        |> mes("What are you waiting")
        |> mes("for?! It's important that")
        |> mes("you give that file to the")
        |> mes("president as soon as")
        |> mes("possible! It's bad news,")
        |> mes("but he deserves to know...")
        |> close()

      quest == 40 ->
        report_betrayal(ctx)

      true ->
        ctx
        |> mes("[Esuna]")
        |> mes("..........")
        |> mes("......")
        |> mes("....")
        |> close()
    end
  end

  defp report_betrayal(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Esuna]")
      |> mes("Good, you're back.")
      |> mes("Listen, all members of")
      |> mes("Secret Wing need to leave")
      |> mes("the Schwarzwald Republic")
      |> mes("immediately! We've been")
      |> mes("severely compromised...")
      |> next()
      |> select(["What happened?"])

    case choice do
      1 -> explain_betrayal(ctx)
      _ -> ctx
    end
  end

  defp explain_betrayal(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Esuna]")
      |> mes("We've been tremendously")
      |> mes("damaged. A lot of agents")
      |> mes("died to give us this intel,")
      |> mes("but we've been betrayed.")
      |> mes("The president's closest")
      |> mes("aide totally sold us out...")
      |> next()
      |> select(["Who could have done such....?"])

    case choice do
      1 ->
        ctx
        |> mes("[Esuna]")
        |> mes("I can't believe Kurelle")
        |> mes("did this to us. And there's no")
        |> mes("way we can save the president.")
        |> mes("Even if we wanted to, we need")
        |> mes("to stick with our contigency")
        |> mes("plan. We all knew the risks...")
        |> next()
        |> mes("[Esuna]")
        |> mes("Kurelle has been secretly")
        |> mes("meeting with directors from")
        |> mes("Rekenber Corporation and")
        |> mes("his mansion is littered with")
        |> mes("incriminating evidence...")
        |> next()
        |> mes("[Esuna]")
        |> mes("Damn it! We have no")
        |> mes("choice but to abandon")
        |> mes("the president now! But")
        |> mes("this won't mean that his")
        |> mes("sacrifice, and Jargeah's")
        |> mes("death, will be vain!")
        |> next()
        |> mes("[Esuna]")
        |> mes("Still, aside from a few")
        |> mes("agents, almost all of Secret")
        |> mes("Wing must pull out of the")
        |> mes("Schwarzwald Republic for")
        |> mes("now so that we can live to")
        |> mes("fight another day.")
        |> next()
        |> mes("[Esuna]")
        |> mes("For now, this is")
        |> mes("goodbye. Take care...")
        |> set_char_var(:lhz_boss, 41)
        |> changequest(12_027, 12_028)
        |> close2()
        |> disablenpc("Mysterious Woman")

      _ ->
        ctx
    end
  end
end
